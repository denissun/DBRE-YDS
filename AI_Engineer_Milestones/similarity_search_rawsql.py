import psycopg2
import os
from sqlalchemy.sql import func
from pgvector.sqlalchemy import Vector
from pgvector.psycopg2 import register_vector
import numpy as np
from google import genai



def generate_embeddings(text_chunks):
    embeddings = []
    for chunk in text_chunks:
        result = client.models.embed_content(model="text-embedding-004", contents=chunk)
        [emb]=result.embeddings
        embeddings.append(emb.values)
    return embeddings



# Cosine Distance = 1 - Cosine Similarity. A higher cosine similarity score indicates greater similarity, 
# while a lower cosine distance score indicates greater similarity. 

#  <=> operator 

def get_top_similar_embeddings(query_embedding, nlimit,  conn):
    embedding_array = np.array(query_embedding)
    # Register pgvector extension
    register_vector(conn)
    cur = conn.cursor()
    # Get the top 3 most similar documents using the KNN <=> operator
    cur.execute("SELECT event_id, title, embedding <=> %s as similarity  FROM event_title_embeddings ORDER BY embedding <=> %s LIMIT %s", (embedding_array, embedding_array, nlimit))
    top_emb = cur.fetchall()
    return top_emb

def get_top_similar_embeddings_jira_pct196(query_embedding, nlimit,  conn):
    embedding_array = np.array(query_embedding)
    # Register pgvector extension
    register_vector(conn)
    cur = conn.cursor()
    # Get the top 3 most similar documents using the KNN <=> operator
    cur.execute("SELECT key, summary, application, embedding <=> %s as similarity  FROM pct196_jira_embeddings ORDER BY embedding <=> %s LIMIT %s", (embedding_array, embedding_array, nlimit))
    top_emb = cur.fetchall()
    return top_emb


##############   MAIN  ##################################

print("Enter your query for similarity search: (ctrl-c to exit) \n")
input_query = input()

# input_query='how to do performance tunning with index?'  

print ("Your query: " + input_query)
print ()

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
client = genai.Client(api_key=GEMINI_API_KEY)

# generate query embedding
query_embedding = generate_embeddings([input_query])[0]

conn = psycopg2.connect( os.environ['DB_CONNECTION_STRING']) 

similar_embeddings = get_top_similar_embeddings(query_embedding, 10, conn)

print ("\nTop 10 events based on similarity to your query (the lower score the higher similarity):\n")
for i in similar_embeddings :
   print("event_id:{:>7}  score:{:.3f}  title: {:<}".format(i[0], i[2], i[1])) 

similar_embeddings_pct196 = get_top_similar_embeddings_jira_pct196(query_embedding, 10,  conn)

print ("\nTop 10 PCT196 Jira based on similarity to your query (the lower score the higher similarity):\n")
for i in similar_embeddings_pct196 :
   #print("key: {:>20}  summary:{}  application: {}  score:{:.3f}".format(i[0], i[1], i[2], i[3])) 
   print(i)
