#!/usr/bin/env tarantool
local log = require('log')
local shard = require('shard')
local yaml = require('yaml')
local fiber = require('fiber')

local GROUP_INDEX = 4

local function die(msg, ...)
    local err = string.format(msg, ...)
    log.error(err)
    error(err)
end

-- called from a remote server
function load_data(tuples)
    for _, tuple in ipairs(tuples) do
        local status, reason = pcall(function()
            box.space.wiki:insert(tuple)
        end)
        if not status then
            if reason:find('^Duplicate') ~= nil then
                log.error('failed to insert account_id = %s: %s', tuple[1],
                    reason)
            else
                die('failed to insert account_id = %s: %s', tuple[1],
                    reason)
            end
        end
    end
end

local function load_batch(args)
    local server = args[1]
    local tuples = args[2]
    local status, reason = pcall(function()
        server.conn:timeout(5 * shard.REMOTE_TIMEOUT)
            :call("load_data", tuples)
    end)
    if not status then
        log.error('failed to insert on %s: %s', server.uri, reason)
        if not server.conn:is_connected() then
            log.error("server %s is offline", server.uri)
        end
    end
end

local function process_cat(name, tuples)
    local data = box.space.cat:select{name}
    if data[1] == nil then
        shard.cat:insert{name}
    end
    shard.cat:update(name, tuples)
end

local function compute()
    local pages = box.space.wiki:select{}
    for _, page in pairs(pages) do
        if page[GROUP_INDEX][1] ~= nil then
            local data = {}
            local i = 1
            for _, cat in pairs(page[GROUP_INDEX]) do
                shard.cat:auto_increment{cat, page[1]}
                i = i + 1
            end
            --collectgarbage('collect')
        end
    end
end

local function bulk_load(self, data, count)
    -- Start fiber queue to processes requests in parallel
    local batches = {}
    local i = 0
    for _, tuple_data in ipairs(data) do
        local data_id = tuple_data[1]
        if data_id then
            local tuple = box.tuple.new(tuple_data)
            for _, server in ipairs(shard.shard(data_id)) do
                local batch = batches[server]
                if batch == nil then
                    batch = { count = 0, tuples = {} }
                    batches[server] = batch
                end
                batch.count = batch.count + 1
                batch.tuples[batch.count] = tuple
            end
        else
            die('invalid line in bulk_load: [%s]', line) 
        end
       i = i + 1
    end
    local q = shard.queue(load_batch, shard.len())
    for server, batch in pairs(batches) do
        q:put({ server, batch.tuples })
    end
    -- stop fiber queue
    q:join()
    --log.info('loaded %s tuples', i)
    batches = nil
    collectgarbage('collect')
end

-- check shard after connect function
shard.check_shard = function(conn)
    return conn.space.wiki ~= nil
end

--
-- Entry point
--
local function start(cfg)
    -- Configure database
    -- Create users && tables
    if not box.space.wiki then
        log.info('bootstraping database...')
        box.schema.user.create(cfg.login, { password = cfg.password })
        box.schema.user.grant(cfg.login, 'read,write,execute', 'universe')
        local wiki = box.schema.create_space('wiki')
        wiki:create_index('primary', {type = 'hash', parts = {1, 'num'}})
        wiki:create_index('title', {type = 'hash', parts = {3, 'str'}})
        log.info('bootstrapped') 
        local cat = box.schema.create_space('cat')
        cat:create_index('primary', {type = 'tree', parts = {1, 'num'}})
        cat:create_index('second', {type = 'tree', unique=false, parts = {2, 'str'}})
    end

    -- Start binary port
    box.cfg { listen = cfg.binary }

    -- Initialize sharding
    shard.init(cfg)
    log.info('started')
    return true
end

local function test()
    log.info(yaml.encode(box.space.wiki:select()))
    log.info(yaml.encode(box.space.cat:select()))
end

local function lookup(word)
    local result = {}
    local count = 1
    log.info('lookup: %s', word)
    groups = box.space.wiki.index.title:select(word)[1][GROUP_INDEX]

    for _, name in pairs(groups) do
        if string.match(name, 'Вики') == nil then
        local data = box.space.cat.index[1]:select(name, {limit=100})
        log.info('category count=%d', #data)
        for _, tuple in pairs(data) do
            local id = tuple[3]
            if type(id) == 'number' then
                result[count] = box.space.wiki:get(id)
                count = count + 1
            end
        end
        end
    end
    return result
end

return {
    start = start,
    bulk_load = bulk_load,
    lookup = lookup,
    compute = compute,
    test = test,
}
-- vim: ts=4:sw=4:sts=4:et

