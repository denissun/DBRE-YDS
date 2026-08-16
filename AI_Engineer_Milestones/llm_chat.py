# Program: llm_chat.py
#
# An example of RAG: Retrieval Augmented Generation, 
# retrieve relevant data from our vector database 
# give it to the LLM as context to use when it generates a response to a prompt.

import os
from  google import genai
from google.genai import types
import psycopg2
import numpy as np
from pgvector.psycopg2 import register_vector



def generate_embeddings(text_chunks):
    embeddings = []
    for chunk in text_chunks:
        result = client.models.embed_content(model="text-embedding-004", contents=chunk)
        [emb]=result.embeddings
        embeddings.append(emb.values)
    return embeddings

def get_top_similar_embeddings(query_embedding, nlimit,  conn):
    embedding_array = np.array(query_embedding)
    # Register pgvector extension
    register_vector(conn)
    cur = conn.cursor()
    cur.execute("SELECT event_id, title, embedding <=> %s as similarity  FROM event_title_embeddings ORDER BY embedding <=> %s LIMIT %s", (embedding_array, embedding_array, nlimit))
    top_emb = cur.fetchall()
    return top_emb

def create_rag_prompt(query, context):
    prompt = f"""
    INSTRUCTIONS: 
    You are an expert Oracle database administrator, based on the context provided, you can explain how to do things to any junior to mid-level DBAs. 
    Please limit your answer within 2000 characters

    CONTEXT:
    {context}

    QUESTION:
    {query}

    ANSWER:
    """
    return prompt

def create_rag_prompt2(query, context):
    prompt = f"""
    INSTRUCTIONS: 
    Based on the context provided, you can summarize and give a narrative about what are the tasks or activities DBA performed. 
    Please limit your answer within 2000 characters

    CONTEXT:
    {context}

    QUESTION:
    {query}

    ANSWER:
    """
    return prompt


######################  MAIN  #################################

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
client = genai.Client(api_key=GEMINI_API_KEY)

print("Ask a question to your expert DBA AI Assistant: (ctrl-c to exit) \n")
query = input()


print ("Your query: " + query)
print ()


# generate query embedding
query_embedding = generate_embeddings([query])[0]
conn = psycopg2.connect( os.environ['DB_CONNECTION_STRING'])
similar_embeddings = get_top_similar_embeddings(query_embedding, 10, conn)
context_list=[]

# build context
print ("========== Your DBA AI will answer your questins based on the following context ==================")
for i in similar_embeddings :
   context_list.append(i[1])
   print("event_id:{:>7}  score:{:.3f}  title: {:<}".format(i[0], i[2], i[1]))

context=". ".join(context_list)


# context="in SSP ordering databases there are multiple expensive query doing full table scan . I/O usage is high"


prompt=create_rag_prompt(query, context)

response = client.models.generate_content(
    model="gemini-2.0-flash-001",
    contents= prompt 
)

print ("\n\n\n======= How to do things as a DBA  =========================================================")
print ("Question: "  + query )
print ("Answer: "  )
print(response.text)

prompt=create_rag_prompt2(query, context)

response = client.models.generate_content(
    model="gemini-2.0-flash-001",
    contents= prompt 
)

print ("\n\n\n======= Your DBA AI is giving summarization ==================================================")
print ("Question: "  + query )
print ("Answer: "  )
print(response.text)
