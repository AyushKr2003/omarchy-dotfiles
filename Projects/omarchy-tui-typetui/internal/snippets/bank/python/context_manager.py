class DatabaseConnection:
    def __init__(self, host, port, database):
        self.host = host
        self.port = port
        self.database = database
        self.connection = None

    def __enter__(self):
        self.connection = connect(
            host=self.host,
            port=self.port,
            database=self.database,
        )
        return self.connection

    def __exit__(self, exc_type, exc_value, traceback):
        if self.connection is not None:
            if exc_type is not None:
                self.connection.rollback()
            else:
                self.connection.commit()
            self.connection.close()
        return False


def run_query(host, port, database, query):
    with DatabaseConnection(host, port, database) as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        return cursor.fetchall()
