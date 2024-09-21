import os
import subprocess

# Get the password from the environment variable
password = os.environ.get('PGPASSWORD')

if not password:
    raise ValueError("PGPASSWORD environment variable is not set")

# Set up the pg_dump command
pg_dump_command = [
    'pg_dump',
    '-h', 'aws-0-ap-southeast-2.pooler.supabase.com',
    '-p', '5432',
    '-U', 'postgres.veobbohczqraqzcaobvw',
    '-d', 'postgres',
    '--schema', 'public',
    '--schema-only',
    '-f', 'schema_dump.sql'
]

# Set the PGPASSWORD environment variable for the subprocess
env = os.environ.copy()
env['PGPASSWORD'] = password

try:
    # Run the pg_dump command
    result = subprocess.run(pg_dump_command, env=env, check=True, capture_output=True, text=True)
    print("Schema dump completed successfully.")
    print(f"Output saved to schema_dump.sql")
except subprocess.CalledProcessError as e:
    print(f"An error occurred while dumping the schema: {e}")
    print(f"Error output: {e.stderr}")
except FileNotFoundError:
    print("pg_dump command not found. Make sure it's installed and in your PATH.")
