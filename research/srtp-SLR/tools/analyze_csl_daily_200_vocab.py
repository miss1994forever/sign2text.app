#!/usr/bin/env python3

import argparse
import csv
import gzip
import json
import os
import pickle
import urllib.request
from collections import Counter


RAW_BASE_URL = "https://raw.githubusercontent.com/ZechengLi19/Uni-Sign/main/data/CSL_Daily"
DEFAULT_LOCAL_DIR = "/tmp/csl_daily_data"


def load_label_file(source):
    if os.path.exists(source):
        with gzip.open(source, "rb") as handle:
            return pickle.load(handle)

    with urllib.request.urlopen(source) as response:
        payload = response.read()
    return pickle.loads(gzip.decompress(payload))


def load_splits(local_dir):
    splits = {}
    for split in ("train", "dev", "test"):
        local_path = os.path.join(local_dir, "labels.%s" % split)
        source = local_path if os.path.exists(local_path) else "%s/labels.%s" % (RAW_BASE_URL, split)
        splits[split] = load_label_file(source)
    return splits


def count_split(sample_dict):
    token_counter = Counter()
    sample_counter = Counter()
    total_tokens = 0

    for sample in sample_dict.values():
        glosses = sample.get("gloss", [])
        total_tokens += len(glosses)
        token_counter.update(glosses)
        sample_counter.update(set(glosses))

    return {
        "samples": len(sample_dict),
        "tokens": total_tokens,
        "types": len(token_counter),
        "token_counter": token_counter,
        "sample_counter": sample_counter,
    }


def select_top_vocab(train_stats, top_n):
    ranked = sorted(
        train_stats["token_counter"].items(),
        key=lambda item: (-item[1], -train_stats["sample_counter"][item[0]], item[0]),
    )
    return [gloss for gloss, _ in ranked[:top_n]]


def evaluate_selection(sample_dict, selected_vocab):
    selected_vocab = set(selected_vocab)
    total_samples = len(sample_dict)
    exact_covered_samples = 0
    total_tokens = 0
    covered_tokens = 0
    total_unique_types = set()
    covered_unique_types = set()

    for sample in sample_dict.values():
        glosses = sample.get("gloss", [])
        gloss_set = set(glosses)
        total_unique_types.update(gloss_set)
        covered_unique_types.update(gloss_set & selected_vocab)

        total_tokens += len(glosses)
        covered_tokens += sum(1 for gloss in glosses if gloss in selected_vocab)
        if all(gloss in selected_vocab for gloss in glosses):
            exact_covered_samples += 1

    return {
        "samples": total_samples,
        "exact_covered_samples": exact_covered_samples,
        "exact_sample_coverage": exact_covered_samples / total_samples if total_samples else 0.0,
        "tokens": total_tokens,
        "covered_tokens": covered_tokens,
        "token_coverage": covered_tokens / total_tokens if total_tokens else 0.0,
        "types": len(total_unique_types),
        "covered_types": len(covered_unique_types),
        "type_coverage": len(covered_unique_types) / len(total_unique_types) if total_unique_types else 0.0,
    }


def build_vocab_rows(vocab_list, split_stats):
    train_tokens_total = split_stats["train"]["tokens"]
    cumulative_tokens = 0
    rows = []

    for rank, gloss in enumerate(vocab_list, start=1):
        train_token_count = split_stats["train"]["token_counter"][gloss]
        cumulative_tokens += train_token_count
        rows.append(
            {
                "rank": rank,
                "gloss": gloss,
                "train_token_count": train_token_count,
                "train_sample_count": split_stats["train"]["sample_counter"][gloss],
                "dev_token_count": split_stats["dev"]["token_counter"][gloss],
                "test_token_count": split_stats["test"]["token_counter"][gloss],
                "all_token_count": sum(split_stats[split]["token_counter"][gloss] for split in ("train", "dev", "test")),
                "cumulative_train_token_coverage": cumulative_tokens / train_tokens_total if train_tokens_total else 0.0,
            }
        )

    return rows


def write_csv(path, rows):
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "rank",
                "gloss",
                "train_token_count",
                "train_sample_count",
                "dev_token_count",
                "test_token_count",
                "all_token_count",
                "cumulative_train_token_coverage",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)


def write_markdown(path, top_n, split_stats, evaluation, rows):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("# CSL-Daily %d-word vocabulary analysis\n\n" % top_n)
        handle.write("This report uses the public Uni-Sign CSL-Daily label files and selects the top-%d glosses by training token frequency. This selection is exactly optimal for training token coverage; the reported token and sample coverage values are exact for that selected set.\n\n" % top_n)

        handle.write("## Split stats\n\n")
        handle.write("| Split | Samples | Gloss tokens | Unique gloss types |\n")
        handle.write("| --- | ---: | ---: | ---: |\n")
        for split in ("train", "dev", "test"):
            stats = split_stats[split]
            handle.write("| %s | %d | %d | %d |\n" % (split, stats["samples"], stats["tokens"], stats["types"]))

        handle.write("\n## Exact coverage for the selected %d-word vocabulary\n\n" % top_n)
        handle.write("| Split | Token coverage | Covered tokens | Exact sample coverage | Covered samples | Type coverage |\n")
        handle.write("| --- | ---: | ---: | ---: | ---: | ---: |\n")
        for split in ("train", "dev", "test"):
            stats = evaluation[split]
            handle.write(
                "| %s | %.4f%% | %d / %d | %.4f%% | %d / %d | %.4f%% |\n"
                % (
                    split,
                    stats["token_coverage"] * 100.0,
                    stats["covered_tokens"],
                    stats["tokens"],
                    stats["exact_sample_coverage"] * 100.0,
                    stats["exact_covered_samples"],
                    stats["samples"],
                    stats["type_coverage"] * 100.0,
                )
            )

        handle.write("\n## Top-%d candidate table\n\n" % top_n)
        handle.write("| Rank | Gloss | Train token freq | Train sample freq | Dev token freq | Test token freq | All token freq | Cum. train token coverage |\n")
        handle.write("| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |\n")
        for row in rows:
            handle.write(
                "| %(rank)d | %(gloss)s | %(train_token_count)d | %(train_sample_count)d | %(dev_token_count)d | %(test_token_count)d | %(all_token_count)d | %(coverage).4f%% |\n"
                % {
                    "rank": row["rank"],
                    "gloss": row["gloss"],
                    "train_token_count": row["train_token_count"],
                    "train_sample_count": row["train_sample_count"],
                    "dev_token_count": row["dev_token_count"],
                    "test_token_count": row["test_token_count"],
                    "all_token_count": row["all_token_count"],
                    "coverage": row["cumulative_train_token_coverage"] * 100.0,
                }
            )


def to_json_ready(split_stats, evaluation, rows):
    return {
        "split_stats": {
            split: {
                "samples": split_stats[split]["samples"],
                "tokens": split_stats[split]["tokens"],
                "types": split_stats[split]["types"],
            }
            for split in ("train", "dev", "test")
        },
        "evaluation": evaluation,
        "top_vocab": rows,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--top-n", type=int, default=200)
    parser.add_argument(
        "--local-dir",
        default=DEFAULT_LOCAL_DIR,
        help="Directory containing labels.train/labels.dev/labels.test. Falls back to GitHub raw URLs when files are absent.",
    )
    parser.add_argument(
        "--output-dir",
        default="/home/haojun/projects/sign2text.app/research/srtp-SLR/outputs/csl_daily_200_vocab",
    )
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    split_data = load_splits(args.local_dir)
    split_stats = {split: count_split(split_data[split]) for split in ("train", "dev", "test")}
    selected_vocab = select_top_vocab(split_stats["train"], args.top_n)
    evaluation = {split: evaluate_selection(split_data[split], selected_vocab) for split in ("train", "dev", "test")}
    rows = build_vocab_rows(selected_vocab, split_stats)

    csv_path = os.path.join(args.output_dir, "top_%d_vocab.csv" % args.top_n)
    md_path = os.path.join(args.output_dir, "report_top_%d_vocab.md" % args.top_n)
    json_path = os.path.join(args.output_dir, "report_top_%d_vocab.json" % args.top_n)

    write_csv(csv_path, rows)
    write_markdown(md_path, args.top_n, split_stats, evaluation, rows)
    with open(json_path, "w", encoding="utf-8") as handle:
        json.dump(to_json_ready(split_stats, evaluation, rows), handle, ensure_ascii=False, indent=2)

    print(json.dumps({
        "output_dir": args.output_dir,
        "csv": csv_path,
        "markdown": md_path,
        "json": json_path,
        "selected_vocab_size": len(selected_vocab),
        "train_token_coverage": evaluation["train"]["token_coverage"],
        "train_exact_sample_coverage": evaluation["train"]["exact_sample_coverage"],
        "dev_token_coverage": evaluation["dev"]["token_coverage"],
        "dev_exact_sample_coverage": evaluation["dev"]["exact_sample_coverage"],
        "test_token_coverage": evaluation["test"]["token_coverage"],
        "test_exact_sample_coverage": evaluation["test"]["exact_sample_coverage"],
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()