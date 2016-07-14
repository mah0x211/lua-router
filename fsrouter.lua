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

  fsrouter.lua
  lua-fsrouter
  Created by Masatoshi Teruya on 13/03/15.

--]]

-- modules
local vardir = require('vardir');
local RootDir = require('rootdir');
local tblconcat = table.concat;
-- constants
local EREADDIR = 'failed to readdir %s: %s';
local ESETROUTE = 'failed to set route %s: %s';
local ECOMPILE = 'failed to compile %s: %s';
local ELINK = 'failed to link %s: %s';
-- default values
local function DO_NOTHING()end
local DEFAULT_TRANSPILER = {
    setup = DO_NOTHING,
    cleanup = DO_NOTHING,
    push = DO_NOTHING,
    pop = DO_NOTHING,
    compile = DO_NOTHING,
    link = DO_NOTHING
};

-- private function
local function traversedir( own, route, errtbl, dir )
    local transpiler = own.transpiler;
    local entries, err = own.rootdir:readdir( dir );

    -- got error
    if err then
        errtbl[#errtbl + 1] = EREADDIR:format( dir, err );
        return #errtbl;
    elseif entries.reg then
        local files = {};
        local ok, ignore, rpath;

        -- check regular files
        for _, stat in ipairs( entries.reg ) do
            -- compile script file
            ignore, err = transpiler:compile( stat )
            -- got error
            if err then
                errtbl[#errtbl + 1] = ECOMPILE:format( stat.rpath, err );
            -- regular file
            elseif not ignore then
                files[#files + 1] = stat;
            end
        end

        -- link
        for i = 1, #files do
            err = transpiler:link( files[i] );
            if err then
                errtbl[#errtbl + 1] = ELINK:format( files[i].rpath, err );
            -- set stat to router
            else
                -- eliminate a file extension from routing params
                rpath = files[i].rpath:gsub( '(@[^/]+)%.[%w%.]+$', '%1' );
                ok, err = route:set( rpath, files[i] );
                if not ok then
                    errtbl[#errtbl + 1] = ESETROUTE:format( files[i].rpath, err );
                end
            end
        end
    end

    -- traverse directories
    if entries.dir then
        for _, stat in ipairs( entries.dir ) do
            transpiler:push( stat.rpath );
            traversedir( own, route, errtbl, stat.rpath );
            transpiler:pop();
        end
    end

    return #errtbl;
end

-- class
local FSRouter = require('halo').class.FSRouter;


function FSRouter:init( cfg )
    local own = protected( self );
    local err;

    -- check transpiler
    if cfg.transpiler then
        local transpiler = cfg.transpiler;

        for k, t in pairs({
            setup = 'function',
            cleanup = 'function',
            push = 'function',
            pop = 'function',
            compile = 'function',
            link = 'function',
        }) do
            if type( transpiler[k] ) ~= t then
                error( 'cfg.transpiler.' .. k .. ' must be function' );
            end
        end
        own.transpiler = transpiler;
    else
        own.transpiler = DEFAULT_TRANSPILER;
    end

    own.rootdir = RootDir.new( cfg );
    -- traverse rootdir
    err = self:readdir();
    if err then
        error( err );
    end

    return self;
end


function FSRouter:readdir()
    local own = protected( self );
    local route = vardir.new( '@' );
    local errtbl = {};

    -- traverse rootdir and run transpiler
    own.transpiler:setup();
    if traversedir( protected( self ), route, errtbl, '/' ) > 0 then
        return tblconcat( errtbl, '\n' );
    end
    own.transpiler:cleanup();

    -- replace current route
    own.route = route;
end


function FSRouter:lookup( uri )
    return protected( self ).route:resolve( uri );
end


return FSRouter.exports;
