# platbot

set DATABASE_URL (environment valuable)  
set data.rb (bot config)

execute sql below  
`create table plat (channel_id integer primary key, server_id integer, description text, cap integer, leader integer, member_id_list text, queue_id_list text, created_at integer);`  
`create table name (id integer, name text);`
