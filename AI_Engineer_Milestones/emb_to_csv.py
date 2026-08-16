# Script: emb_to_csv.py
# create embeddings and save in csv file
#

from google import genai
import os
import pandas as pd

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
client = genai.Client(api_key=GEMINI_API_KEY)


#####  source data #########
docs=[
 'top 10 sqls in term of total buffer_gets in past  7 days'
 ,'spfprdsc - 11trc93bakbv0 sql tunning'
 ,'CHG000687137 - Infomanager - sasmwkspldp01/02 is being retired'
]


#### create embedings
# text-embedding-004
# https://ai.google.dev/gemini-api/docs/models#embedding
# Input token limit 2,048 Output dimension size 768

docs_emb = []

for i in range(len(docs)) :
    result = client.models.embed_content(model="text-embedding-004", contents=docs[i])
    [emb]=result.embeddings
    docs_emb.append([docs[i], emb.values])
 

#### save embedings to csv
# Create a new dataframe from the list
df_new = pd.DataFrame(docs_emb, columns=['content', 'embedding'])
df_new.to_csv('docs.csv', index=False)
