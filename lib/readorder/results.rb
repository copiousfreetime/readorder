require 'amalgalite'

module Readorder
  # Results persists the results from a readorder run
  # The results are persisted in an SQlite3 database which allows for ordering
  # the results by whatever means are wanted.
  class Results
    def self.create_table_sql
      sql = <<-SQL
        CREATE TABLE readorder_valid ( 
           original_order              INTEGER PRIMARY KEY NOT NULL,
           size                        INTEGER NOT NULL,
           inode_number                INTEGER NOT NULL UNIQUE,
           first_physical_block_number INTEGER UNIQUE,
           physical_block_count        INTEGER,
           filename                    TEXT    NOT NULL UNIQUE
        );

        CREATE TABLE readorder_errors (
           original_order              INTEGER PRIMARY KEY NOT NULL,
           filename                    TEXT NOT NULL UNIQUE,
           error_reason                TEXT NOT NULL
        );
      SQL
    end

    def initialize( filename )
      @db = Amalgalite::Database.new( filename )

      unless @db.schema.tables['readorder_results'] then
        logger.info "Creating tables"
        @db.execute_batch( Results.create_table_sql )
      end
      @db.reload_schema!
    end

    def close
      @db.close
    end

    def logger
      Logging::Logger[ self ]
    end

    #
    # :call-seq:
    #   results.add_datum( datum )
    #
    # add a datum to the database, this will insert the datum into either valid
    # or errors depending on the state of datum.valid?
    #
    def add_datum( datum )
      if datum.valid?
        add_valid( datum )
      else
        add_error( datum )
      end
    end

    #
    # :call-seq:
    #   results.add_valid( datum ) 
    #
    # Add a valid datum to the valid valid
    #
    def add_valid( datum )
      logger.info "Adding datum for #{datum.filename}"
      sql = <<-insert
      INSERT INTO readorder_valid ( original_order, 
                                    size,
                                    inode_number,
                                    first_physical_block_number,
                                    physical_block_count,
                                    filename )
      VALUES( ?, ?, ?, ?, ?, ? );
      insert

      @db.execute( sql, datum.original_order,
                        datum.size,
                        datum.inode_number,
                        datum.first_physical_block_number,
                        datum.physical_block_count,
                        datum.filename
      )
    end

    #  :call-seq:
    #    results.valid_count -> Integer
    #
    # return the number of valid result rows
    #
    def valid_count
      @db.first_value_from( "SELECT count(original_order) FROM readorder_valid" )
    end


    #
    # :call-seq:
    #   results.each_valid { |v| ... }
    #
    # Return each valid record without any predefined order
    #
    def each_valid( &block )
      @db.execute( "SELECT * FROM readorder_valid" ) do |row|
        yield row
      end
    end

    #
    # :call-seq:
    #   results.each_valid_by_physical_block_number { |v| ... }
    #
    # Return each valid record in physical block number order
    #
    def each_valid_by_first_physical_block_number( &block )
      each_valid_by_field( 'first_physical_block_number' ) do |row|
        block.call( row )
      end
    end

    #
    # :call-seq:
    #   results.each_valid_by_inode_number { |v| ... }
    #
    def each_valid_by_inode_number( &block )
      each_valid_by_field( 'inode_number' ) do |row|
        block.call( row )
      end
    end

    #
    # :call-seq:
    #   results.each_valid_by_field( field ) { |v| ... }
    #
    def each_valid_by_field( field, &block )
      @db.execute( "SELECT * from readorder_valid ORDER BY #{field} ASC" ) do |row|
        yield row
      end
    end

    # :call-seq:
    #   results.add_error( Datum ) -> nil
    #
    # Add a datum that records an error into the results.
    #
    def add_error( datum )
      sql = <<-insert
      INSERT INTO readorder_errors ( original_order, filename, error_reason )
      VALUES( ?, ?, ? );
      insert
      @db.execute( sql, datum.original_order, 
                        datum.filename,
                        datum.error_reason 
      )
    end

    #  :call-seq:
    #    results.error_count -> Integer
    #
    # return the number of errors
    #
    def error_count
      @db.first_value_from( "SELECT count(original_order) FROM readorder_errors" )
    end

    #
    # :call-seq:
    #   results.each_error { |e| ... }
    #
    # Return each error record without any predefined order
    #
    def each_error( &block )
      @db.execute( "SELECT * FROM readorder_errors" ) do |row|
        yield row
      end
    end


  end
end
