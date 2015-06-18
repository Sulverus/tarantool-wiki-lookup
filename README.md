# tarantool-wiki-lookup

This is 'how-to' project.

Main purpose of this project is to demonstrate how to handle big dataset by using Tarantool Nginx module and Tarantool Shard for work with big and complex dataset.

'big/complex dataset' are Wikipedia's categories.

Main functional is:
 - upload wikipedia's dumps into Tarantool;
 - search through uploaded Wikipedia's categories.

###Stack:

[Wiki dumps](http://dumps.wikimedia.org)

[Tarantool](http://tarantool.org)

[Sharding](https://github.com/tarantool/shard)

[Nginx upstream module](https://github.com/tarantool/nginx_upstream_module)

[Web UI](https://github.com/Sulverus/tarantool-wiki-lookup/tree/master/web)

###Example
View [live demo](http://wiki.build.tarantool.org)
