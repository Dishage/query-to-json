import psycopg2
import json
from psycopg2.extras import RealDictCursor

# Database connection details
db_config = {
      "host": "aws-0-ap-southeast-2.pooler.supabase.com",
      "port": "5432",
      "database": "postgres",
      "user": "postgres.veobbohczqraqzcaobvw",
      "password": ""  # Password will be set from environment variable
}

# SQL query
sql_query = """
SELECT
    schemaname,
        tablename,
            policyname,
                permissive,
                    roles,
                        cmd,
                            qual,
                                with_check
                                FROM
                                    pg_policies
                                    WHERE
                                        schemaname = 'public'
                                            AND tablename = 'z_channel_messages';
                                            """

def fetch_and_save_json():
      try:
                # Get password from environment variable
                import os
                db_config["password"] = os.environ.get("Password")

          # Connect to the database
                conn = psycopg2.connect(**db_config)

          # Create a cursor that returns results as dictionaries
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                              # Execute the query
                              cur.execute(sql_query)

                    # Fetch all results
                              results = cur.fetchall()

                    # Convert results to JSON
                              json_results = json.dumps(results, indent=2, default=str)

                    # Save JSON to file
                              with open('query_results.json', 'w') as f:
                                                f.write(json_results)

                              print("Query results have been saved to query_results.json")

except Exception as e:
        print(f"An error occurred: {e}")

finally:
        if conn:
                      conn.close()

  if __name__ == "__main__":
        fetch_and_save_json()
    
