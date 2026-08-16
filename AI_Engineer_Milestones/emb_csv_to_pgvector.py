# Script: emb_csv_to_pgvector.py
#    save embeddings from csv to PostgreSQL table
#
import os
import pandas as pd
import numpy as np
import ast
import psycopg2
import pgvector
from psycopg2.extras import execute_values
from pgvector.psycopg2 import register_vector


CSV_INPUT='events_title_embedding.csv'
connection_string  = os.environ['DB_CONNECTION_STRING'] 

# print(connection_string)

conn = psycopg2.connect(connection_string)
cur = conn.cursor()

# Register the vector type with psycopg2
register_vector(conn)

# Create table to store embeddings and metadata
table_create_command = """
CREATE TABLE IF NOT EXISTS event_title_embeddings (
            event_id bigint,
            title text,
            embedding vector(768)
            );
            """

cur.execute(table_create_command)
cur.close()
conn.commit()


# load embedding from csv to a DataFrame 
df = pd.read_csv(CSV_INPUT)
# print(df.head())

event_id=df['event_id']
title = df['title']
embeds = [list(map(float, ast.literal_eval(embed_str))) for embed_str in df['embedding']]


df_new = pd.DataFrame({
    'event_id' : event_id, 
    'title'  : title,
    'embedding': embeds
})

# Batch insert embeddings and metadata from dataframe into PostgreSQL database

cur=conn.cursor()

# Prepare the list of tuples to insert
data_list = [( row['event_id'], row['title'], np.array(row['embedding'])) for index, row in df_new.iterrows()]
# Use execute_values to perform batch insertion
execute_values(cur, "INSERT INTO event_title_embeddings (event_id,title, embedding) VALUES %s", data_list)
# Commit after we insert all embeddings
conn.commit()

cur.execute("SELECT COUNT(*) as cnt FROM event_title_embeddings")
num_records = cur.fetchone()[0]
print("Number of vector records in table: ", num_records,"\n")

# print the first record in the table, for sanity-checking
cur.execute("SELECT * FROM event_title_embeddings LIMIT 1;")
records = cur.fetchall()
print("First record in table: ", records)
