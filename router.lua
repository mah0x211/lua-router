--[[

  Copyright (C) 2013 Masatoshi Teruya
 
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
 
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

--]]

-- modules
local usher = require('usher');
local util = require('util');
local clone = util.table.clone;
local typeof = util.typeof;
local FS = require('router.fs');
local AccessDDL = require('router.ddl.access');
local FilterDDL = require('router.ddl.filter');
local ContentDDL = require('router.ddl.content');
local MIME = require('router.mime');
-- constants
local DEFAULT = {
    docroot = 'html',
    followSymlink = false,
    index = 'index.htm',
    sandbox = _G
};
-- class
local Router = require('halo').class.Router;

function Router:init( cfg )
    local own = protected( self );
    
    if cfg == nil then
        cfg = DEFAULT;
    else
        assert( typeof.table( cfg ), 'cfg must be type of table' );
        -- create index table
        if cfg.index then
            assert(
                typeof.string( cfg.index ),
                'cfg.index must be type of string'
            );
            assert(
                not cfg.index:find( '/', 1, true ),
                'cfg.index should not include path-delimiter'
            );
        else
            cfg.index = DEFAULT.index;
        end
    end
    
    -- copy values into protected table
    for k, v in pairs( cfg ) do
        own[k] = v;
    end
    
    -- create index table
    own.index = {
        [cfg.index] = true,
        ['@'..cfg.index] = true
    };
    
    -- create mimemap
    own.mime = MIME.new();
    
    -- create fs
    own.fs = FS.new(
        cfg.docroot, cfg.followSymlinks, cfg.ignore, own.mime:extMap()
    );
    
    -- create ddl
    own.ddl = {
        access = AccessDDL.new( cfg.sandbox ),
        filter = FilterDDL.new( cfg.sandbox ),
        content = ContentDDL.new( cfg.sandbox )
    };
    
    -- create usher
    own.route = assert( usher.new('/@/') );
    
    return self;
end


function Router:mimeTypes()
    return clone( protected(self).mime:typeMap() );
end


function Router:readMIMETypes( mimeTypes )
    if not typeof.string( mimeTypes ) then
        return false, 'mimeTypes must be string';
    end
    
    protected(self).mime:readTypes( mimeTypes );
    
    return true;
end


local function parsedir( own, dir, access, filter )
    local entries, err = own.fs:readdir( dir );
    local wildcards = entries.wildcards;
    local scripts;

    if err then
        return err;
    end

    -- compile $access.lua
    if entries.access then
        access, err = own.ddl.access( entries.access.pathname, false, access );
        if err then
            return err;
        end
    end
    
    -- compile $filter.lua
    if entries.filter then
        filter, err = own.ddl.filter( entries.filter.pathname, false, filter );
        if err then
            return err;
        end
    end
    
    -- compile wildcard handler: $*.[ext.]lua
    for _, stat in pairs( wildcards ) do
        stat.handler, err = own.ddl.content( stat.pathname, false, filter );
        if err then
            return err;
        end
    end
    
    -- check entry
    scripts = entries.scripts;
    for entry, stat in pairs( entries.files ) do
        -- add access handler
        stat.access = access;
        
        -- make file handler
        if scripts[entry] then
            -- assign handler table
            stat.handler, err = own.ddl.content(
                scripts[entry].pathname, false, filter
            );
            if err then
                return err;
            end
        -- assign wildcard handler
        elseif wildcards[stat.ext] then
            stat.handler = clone( wildcards[stat.ext].handler );
        end
        
        -- set state to router
        err = own.route:set( stat.rpath, stat );
        if err then
            return ('failed to set route %s: %s'):format( stat.rpath, err );
        -- add dirname(with trailing-slash) if entry is index file
        elseif own.index[entry] then
            entry = stat.rpath:sub( 1, #stat.rpath - #entry );
            err = own.route:set( entry, stat );
            if err then
                return ('failed to set index route %s: %s'):format( entry, err );
            end
        end
    end
    
    -- recursive call
    for _, v in pairs( entries.dirs ) do
        err = parsedir(
            own, v, access and clone( access ), filter and clone( filter )
        );
        if err then
            return err;
        end
    end
end


function Router:readdir()
    return parsedir( protected( self ), '/' );
end


function Router:lookup( uri )
    return protected( self ).route:exec( uri );
end


function Router:dump()
    protected( self ).route:dump();
end


return Router.exports;

