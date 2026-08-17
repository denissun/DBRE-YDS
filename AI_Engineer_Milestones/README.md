# AI Engineer Milestones

A collection of Python scripts exploring AI/LLM engineering concepts and demonstrating embedding generation, vector storage, and semantic search workflows using Google's Gemini API and PostgreSQL pgvector extension.

## Overview

This folder demonstrates a practical pipeline for:
1. Generating embeddings from text content using Gemini's embedding model
2. Storing embeddings in PostgreSQL with pgvector for semantic search
3. Building AI-powered applications with vector databases

## Scripts

### `emb_to_csv.py` - Generate Embeddings and Export to CSV

**Purpose**: Create text embeddings using Google's Gemini API and save them to a CSV file.

**What it does**:
- Accepts a list of text documents (e.g., database incidents, SQL issues, change requests)
- Uses Google's `text-embedding-004` model to generate vector embeddings
- Each document is converted to a 768-dimensional vector representation
- Saves document text and embeddings to `docs.csv`

**Key Details**:
- **Model**: `text-embedding-004` (768-dimensional embeddings)
- **Input Limit**: 2,048 tokens per document
- **Dependencies**: `google-genai` library, Gemini API key
- **Output**: CSV file with columns: `content`, `embedding`

**Usage**:
```bash
export GEMINI_API_KEY="your-api-key"
python emb_to_csv.py
```

**Example Input**:
```python
docs=[
    'top 10 sqls in term of total buffer_gets in past 7 days',
    'spfprdsc - 11trc93bakbv0 sql tunning',
    'CHG000687137 - Infomanager - sasmwkspldp01/02 is being retired',
]
```

---

### `emb_csv_to_pgvector.py` - Load Embeddings to PostgreSQL

**Purpose**: Load embeddings from CSV file into PostgreSQL database using the pgvector extension for vector storage and semantic search.

**What it does**:
- Reads embeddings from a CSV file (e.g., `events_title_embedding.csv`)
- Parses embedding vectors from string format to numeric arrays
- Creates a PostgreSQL table with pgvector column type
- Batch inserts embeddings and metadata into the database
- Validates the insert by querying the table

**Key Details**:
- **Database Extension**: `pgvector` (enables vector similarity searches)
- **Table Schema**: 
  - `event_id` (bigint) - Unique event identifier
  - `title` (text) - Document title/content
  - `embedding` (vector(768)) - 768-dimensional embedding vector
- **Dependencies**: `psycopg2`, `pgvector`, `pandas`, `numpy`
- **Input**: CSV file with columns: `event_id`, `title`, `embedding`

**Usage**:
```bash
export DB_CONNECTION_STRING="postgresql://user:password@host:5432/dbname"
python emb_csv_to_pgvector.py
```

**Expected Output**:
```
Number of vector records in table: 42

First record in table: (1, 'Document Title', [0.123, -0.456, ...])
```

---

## Workflow

```
Text Documents
    ↓
[emb_to_csv.py] ← Gemini Embedding API
    ↓
docs.csv (content + embeddings)
    ↓
[emb_csv_to_pgvector.py] → PostgreSQL + pgvector
    ↓
Vector Database (ready for similarity search)
```

## Use Cases

### 1. **Semantic Search for Database Events**
   - Store incident summaries and change requests as embeddings
   - Query by similarity: "Find similar past incidents to this new alert"
   - Find related documents without exact keyword matching

### 2. **SQL Tuning Knowledge Base**
   - Embed SQL tuning guidelines and past solutions
   - Match new performance problems to historical solutions
   - Semantic search across tuning best practices

### 3. **Incident Correlation**
   - Embed incident descriptions and root causes
   - Find similar incidents automatically
   - Build incident relationship graphs

### 4. **RAG (Retrieval-Augmented Generation)**
   - Use embeddings as context retrieval layer
   - Feed relevant documents to LLMs
   - Improve LLM responses with domain-specific knowledge

## Installation

### Prerequisites
- Python 3.8+
- PostgreSQL 12+ with pgvector extension
- Google Gemini API key

### Setup

```bash
# Install Python dependencies
pip install google-genai pandas psycopg2 pgvector numpy

# Install pgvector in PostgreSQL
CREATE EXTENSION IF NOT EXISTS vector;
```

### Environment Variables

```bash
export GEMINI_API_KEY="your-gemini-api-key"
export DB_CONNECTION_STRING="postgresql://user:password@localhost:5432/yourdb"
```

## Embedding Model Details

- **Model Name**: `text-embedding-004`
- **Dimension**: 768
- **Max Input**: 2,048 tokens
- **Cost**: Refer to Google's API pricing
- **Use Case**: General-purpose text embeddings for semantic search

## Database Setup

### Enable pgvector Extension

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### Create Embedding Table

```sql
CREATE TABLE IF NOT EXISTS event_title_embeddings (
    event_id bigint PRIMARY KEY,
    title text,
    embedding vector(768)
);

-- Create index for fast similarity search
CREATE INDEX ON event_title_embeddings USING ivfflat (embedding vector_cosine_ops);
```

### Semantic Search Example

```sql
-- Find top 5 most similar events to a query
SELECT 
    event_id, 
    title, 
    1 - (embedding <=> (SELECT embedding FROM event_title_embeddings LIMIT 1)) as similarity
FROM event_title_embeddings
ORDER BY embedding <=> (SELECT embedding FROM event_title_embeddings LIMIT 1)
LIMIT 5;
```

## Notes

- **Embedding Cost**: Each document embedding call costs tokens; consider batch processing for large datasets
- **Vector Index**: For large tables (>10k rows), create an ivfflat or hnsw index for performance
- **Vector Distance**: pgvector supports cosine, L2, and inner product distances
- **Dimension Mismatch**: Ensure all embeddings are consistently 768 dimensions

## Next Steps

1. Extend with semantic search capabilities
2. Implement RAG pipeline with an LLM
3. Add similarity threshold-based filtering
4. Build vector-based recommendation system
