if exists(select N'?' from sys.database_principals where [name]='demo_reader') begin;
   drop user [demo_reader];
end;

create user [demo_reader] for login [demo_reader];

alter role [db_datareader] add member [demo_reader];