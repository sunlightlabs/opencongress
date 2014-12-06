from textblob import TextBlob
from sys import argv

def get_sentiment(text):
    return TextBlob(text).sentiment

if __name__ == "__main__": print tuple(get_sentiment(argv[1].decode('utf-8')))