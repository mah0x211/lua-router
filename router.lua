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
local typeof = util.typeof;
local FS = require('router.fs');
local Make = require('router.make');
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
    local err;
    
    if not cfg then
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
    
    -- create index table
    self.index = {
        [cfg.index] = true,
        ['@'..cfg.index] = true
    };
    -- create fs
    self.fs = FS.new( cfg.docroot, cfg.followSymlinks, cfg.ignore );
    -- create make
    self.make = Make.new( self.fs, cfg.sandbox );
    -- create usher
    self.route, err = usher.new('/@/');
    assert( not err, err );
    
    return self;
end


-- make handler
local function makeHandler( make, path, tbl )
    local handler, err = make:make( path );
    
    if not err then
        -- merge handler
        for k, v in pairs( handler ) do
            tbl[k] = v;
        end
    end
    
    return err;
end


local function parsedir( self, dir, authHandler, filterHandler )
    local entries, err = self.fs:readdir( dir );
    local basenameHandler = {};
    local handler, scripts, basename, tbl;

    if err then
        return err;
    end

    -- check AUTH_FILE
    if entries.auth then
        err = makeHandler( self.make, entries.auth.rpath, authHandler );
        if err then
            return err;
        end
    end
    -- check FILTER_FILE
    if entries.filter then
        handler, err = self.make:make( entries.filter.rpath );
        if err then
            return err;
        end
        
        -- merge handler
        for method, fn in pairs( handler ) do
            tbl = filterHandler[method];
            if not tbl then
                tbl = { fn };
                filterHandler[method] = tbl;
            else
                tbl[#tbl+1] = fn;
            end
        end
    end

    -- check entry
    scripts = entries.scripts;
    for entry, stat in pairs( entries.files ) do
        -- add auth handler
        stat.auth = authHandler;
        -- add filter handler
        stat.filter = filterHandler;
        
        -- make basename handler
        basename = entry:match('^[^.]+');
        if scripts[basename] then
            tbl = basenameHandler[basename];
            -- not yet compile
            if not tbl then
                tbl = {};
                err = makeHandler( self.make, scripts[basename].rpath, tbl );
                if err then
                    return err;
                else
                    basenameHandler[basename] = tbl;
                end
            end
            
            -- set basename handler
            stat.handler = util.table.copy( tbl );
        end
        
        -- make file handler
        if scripts[entry] then
            handler = stat.handler or {};
            err = makeHandler( self.make, scripts[entry].rpath, handler );
            if err then
                return err;
            elseif handler ~= stat.handler then
                stat.handler = handler;
            end
        end
        
        err = self.route:set( stat.rpath, stat );
        if err then
            return ('failed to set route %s: %s'):format( stat.rpath, err );
        -- add trailing-slash path if entry is index file
        elseif self.index[entry] then
            entry = stat.rpath:sub( 1, #stat.rpath - #entry );
            err = self.route:set( entry, stat );
            if err then
                return ('failed to set index route %s: %s'):format( entry, err );
            end
        end
    end
    
    -- recursive call
    for _, v in pairs( entries.dirs ) do
        err = parsedir( self, v, util.table.copy( authHandler ), 
                        util.table.clone( filterHandler ) );
        if err then
            return err;
        end
    end
end


function Router:readdir()
    return parsedir( self, '/', {}, {} );
end


function Router:lookup( uri )
    return self.route:exec( uri );
end


function Router:dump()
    self.route:dump();
end

return Router.exports;

