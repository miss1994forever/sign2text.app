import React from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

type TranslationDisplayProps = {
  text: string;
};

export default function TranslationDisplay({ text }: TranslationDisplayProps) {
  return (
    <View style={styles.container}>
      <Text style={styles.header}>翻译结果:</Text>
      <ScrollView style={styles.scrollView}>
        <Text style={styles.translationText}>
          {text || '等待翻译...'}
        </Text>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    margin: 20,
    maxHeight: 150,
    backgroundColor: 'white',
    borderRadius: 10,
    padding: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  header: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
    color: '#555',
  },
  scrollView: {
    maxHeight: 100,
  },
  translationText: {
    fontSize: 18,
    lineHeight: 24,
  },
});