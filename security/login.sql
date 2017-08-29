if exists(select N'?' from sys.server_principals where [name]=N'demo_reader') begin;
   alter login [demo_reader] with password=N'demo_reader'
end else begin;
   create login [demo_reader] with password=N'demo_reader', default_database=[master], check_expiration=off, check_policy=off;
end;