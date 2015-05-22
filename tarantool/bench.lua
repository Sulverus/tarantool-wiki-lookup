#!/bin/tarantool

shard = require('shard')
log = require('log')
yaml = require('yaml')
wiki = require('wiki')

box.cfg {
    log_level = 5,
    wal_mode="none",
    slab_alloc_arena=3,
    slab_alloc_factor=1.1,
    slab_alloc_minimal=32,
    pid_file = "tarantool.pid"
}
box.schema.user.grant('guest', 'read,write,execute', 'universe')
conf = {
    servers = {
        { uri = 'localhost:9999', zone = '0' };
        { uri = 'localhost:10000', zone = '1' };
    };
    login = 'tester';
    password = 'pass';
    redundancy = 2;
    binary = 9999;
    monitor = false;
}

wiki.start(conf)

function load(page_id, namespace, title, category_links)
   result = { page_id, namespace, title, category_links }
   wiki:bulk_load({result}, 1)
   return {'DONE'}
end

function lookup(word)
    local l = wiki.lookup(word)
    log.info(yaml.encode(l))
    return l
end

function build()
    wiki.compute()
end
