lua-fsrouter
===

[![test](https://github.com/mah0x211/lua-fsrouter/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-fsrouter/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-fsrouter/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-fsrouter)

lua-fsrouter is a filesystem-based url router based on [lua-plut](https://github.com/mah0x211/lua-plut).


## Installation

```
luarocks install fsrouter
```

## Error Handling

the following functions return the error object created by https://github.com/mah0x211/lua-error module.


## Create a router from the base directory

### r, err, routes = fsrouter.new( pathname [, opts] )

create a new router based on the specified directory.

**Parameters**

- `pathname:string`: path of the base directory.
- `opts:table`
    - `follow_symlink:boolean`: follow symbolic links. (default `false`)
    - `trim_extensions:string[]`: list of extensions to be removed from the route path. (default `{ '.html', '.htm }` )
    - `mimetypes:string`: mime types definition string as the following format. (default: `nil`)
        ```
        #
        # mime types definition
        # this format is based on the nginx mime.types file.
        #
        my/mimetype     my myfile; # my custom mime-type

        # no needs to last semicolon
        application/json json

        # invalid mime type definition
        extension/is-not-declared

        invalid_mime*/type foo # invalid mime type is ignored
        ```
    - `static:string[]`: list of static directories. files except the filter handler files in the listed directories are treated as static files. (default: `nil`)
    - `ignore:string[]`: regular expression for filenames to ignore. (default: `fsrouter.default.ignore`)
    - `no_ignore:string[]`: regular expressions for filenames not to ignore. (default: `fsrouter.default.no_ignore`)
    - `loadfenv:function`: function that returns the environment table of a handler function. (default: `fsrouter.default.loadfenv`)
    - `compiler:function`: function to compile a handler file.  
        ```
        -- Specification of the compiler function
        methods [, err] = compiler( pathname )

        - `pathname:string`: path of the target file.
        - `methods:table<string, function>`: method-name/function pairs.
           method-name must be one of the following names:
             'all' / 'any' / 'get' / 'head' / 'post' / 'put' / 'delete' / 
             'connect' / 'trace' / 'patch'.
        ```
    - `precheck:function`: function to prechecks before adding a route.  
        ```
        -- Specification of the precheck function
        ok, err = precheck( route )

        - `route:table`: path of the target file.
        - `ok:boolean`: return `true` if the route can be added.
        - `err:any`: an error message. if it is not `nil`, abort the traversal.
        ```
    - `router:any`: router object to be used as a router. (default: `nil`)
        ```
        -- Specification of the router object
        -- set a pathname and value pair.
        ok, err = router:set( pathname, val )
        -- lookup a value associated with the specified pathname.
        val, err, glob = router:lookup( pathname )
        ```
        please refer to the [lua-plut](https://github.com/mah0x211/lua-plut) module for more information.


**Returns**

- `r:fsrouter`: instance of fsrouter.
- `err:error`: error message.
- `routes:table[]`: registered routing table.


### URL parameter files and directories

`fsrouter` uses files and directories with the `$` and `*` prefixes as 
parameter segments.

```
html/
├── $user
│   ├── $repo.html
│   └── contents
│       └── *id.html
└── index.html
```

the above directory layout will be converted into the following routing table.

- `/`
- `/:user/:repo`
- `/:user/contents/*id`


### Handler Files

`fsrouter` manages files with the `@` and `#` prefixes as handler files.

the functions described in the handler file are categorized as follows, and 
stored in the `methods` table for each route as method name/functions pairs.

**NOTE: the filter handler will be used in the defined directory and the 
directories under it.**


### Describe handler function

`fsrouter` specifies only how to define a function. the specifications of 
function `arguments` and `return values` are left to the user.

In the default compiler, the handler function should be written as follows.

```lua
-- the handler table is a proxy for registering functions.

-- describe a get handler directly
local function get()
    -- describe the contents...
end

-- describe a post handler locally
local function do_handle_post_request()
    -- describe the contents...
end

return {
    -- assign get function as a get handler
    get = get,
    -- assign do_handle_post_request function as a post handler
    post = do_handle_post_request
}
```

The following names can be specified for the handler name;  

- `all`: this method is only available for filter handlers.
- `any`: this method is used when there is no corresponding method except `all` method.
- `get`, `head`, `post`, `put`, `delete`, `connect`, `trace`, `patch`.




### `@` prefix is used as the content handler file.

```
html/
└── $user
    ├── @index.lua     <-- @index.lua is used as a handler for index.html
    ├── @profile.lua
    └── index.html
```

the above directory layout will be converted into the following routing table.

- `/:user`
- `/:user/profile`

**NOTE:**  if the basename of the handler file matches the basename of a static 
file in the same directory, it will be used as the content handler for the 
matched static file.


### `#` prefix is used as the filter handler file.

```
html/
├── #1.block_ip.lua
├── #2.check_user.lua
├── $user
│   ├── #1.block_user.lua
│   └── index.html
├── index.html
└── signin
    ├── #-.block_ip.lua     <-- disable the #1.block_ip.lua filter handlers
    ├── #-.check_user.lua   <-- disable the #2.check_user.lua filter handlers
    └── index.html
```

the above directory layout will be converted into the following routing table.

- `/`
- `/signin`
- `/:user`


**NOTE:** the number following the `#` prefix indicates the `priority`. smaller numbers 
have higher priority, and the same priority number cannot be specified. also, 
you can disable the filter to specify `-` instead of a number.


## Getting the route value by pathname

### v, err, glob = r:lookup( pathname )

getting the route value in the specified pathname.

**Parameters**

- `pathname:string`: target pathname.

**Returns**

- `val:any`: the route value in the specified pathname.
- `err:error`: an error message.
- `glob:table`: holds the the values of variable segment.



## Example

example document root directory.

```
html/
├── #1.block_ip.lua
├── #2.check_user.lua
├── $user
│   ├── #1.block_user.lua
│   ├── @index.lua
│   ├── @profile.lua
│   ├── index.html
│   ├── posts
│   │   ├── #1.extract_id.lua
│   │   ├── *id.html
│   │   ├── @*id.lua
│   │   ├── @index.lua
│   │   └── index.html
│   └── profile.html
├── @index.lua
├── @settings.lua
├── api
│   └── @index.lua
├── index.html
├── settings.html
└── signin
    ├── #-.block_ip.lua
    ├── #-.check_user.lua
    ├── @index.lua
    └── index.html
```

```lua
local dump = require('dump')
local fsrouter = require('fsrouter')

-- create a new router based on the specified directory
local r = fsrouter.new('html')
-- lookup route
local route, err, glob = r:lookup('/foobar/posts/post-id/hello-my-post')
print(dump({
    route = route,
    err = err,
    glob = glob,
}))
```


<details>
<summary>Output of the above code</summary>

```
{
  glob = {
    id = "post-id/hello-my-post",
    user = "foobar"
  },
  route = {
    file = {
      charset = "us-ascii",
      ctime = 1642664589.0,
      entry = "*id.html",
      ext = ".html",
      mime = "text/html",
      mtime = 1642664589.0,
      pathname = "/***/html/$user/posts/*id.html",
      rpath = "/$user/posts/*id.html",
      size = 10.0,
      type = "file"
    },
    filters = {
      all = {
        [1] = {
          fn = "function: 0x7f92cbe21540",
          name = "block_ip.lua",
          order = 1,
          stat = {
            charset = "us-ascii",
            ctime = 1642664589.0,
            entry = "#1.block_ip.lua",
            ext = ".lua",
            methods = {
              all = "function: 0x7f92cbe21540"
            },
            mtime = 1642664589.0,
            order = 1,
            pathname = "/***/html/#1.block_ip.lua",
            rpath = "/#1.block_ip.lua",
            size = 201.0
          }
        },
        [2] = {
          fn = "function: 0x7f92cbe1f100",
          name = "check_user.lua",
          order = 2,
          stat = {
            charset = "us-ascii",
            ctime = 1642664589.0,
            entry = "#2.check_user.lua",
            ext = ".lua",
            methods = {
              all = "function: 0x7f92cbe1f100"
            },
            mtime = 1642664589.0,
            order = 2,
            pathname = "/***/html/#2.check_user.lua",
            rpath = "/#2.check_user.lua",
            size = 275.0
          }
        },
        [3] = {
          fn = "function: 0x7f92cdd0bc40",
          name = "block_user.lua",
          order = 1,
          stat = {
            charset = "us-ascii",
            ctime = 1642664589.0,
            entry = "#1.block_user.lua",
            ext = ".lua",
            methods = {
              all = "function: 0x7f92cdd0bc40"
            },
            mtime = 1642664589.0,
            order = 1,
            pathname = "/***/html/$user/#1.block_user.lua",
            rpath = "/$user/#1.block_user.lua",
            size = 168.0
          }
        },
        [4] = {
          fn = "function: 0x7f92cdd15280",
          name = "extract_id.lua",
          order = 1,
          stat = {
            charset = "us-ascii",
            ctime = 1642664589.0,
            entry = "#1.extract_id.lua",
            ext = ".lua",
            methods = {
              all = "function: 0x7f92cdd15280"
            },
            mtime = 1642664589.0,
            order = 1,
            pathname = "/***/html/$user/posts/#1.extract_id.lua",
            rpath = "/$user/posts/#1.extract_id.lua",
            size = 170.0
          }
        }
      }
    },
    handler = {
      charset = "us-ascii",
      ctime = 1642664589.0,
      entry = "@*id.lua",
      ext = ".lua",
      methods = {
        any = "function: 0x7f92cdd140a0",
        get = "function: 0x7f92cdd14010"
      },
      mtime = 1642664589.0,
      pathname = "/***/html/$user/posts/@*id.lua",
      rpath = "/$user/posts/@*id.lua",
      size = 173.0
    },
    methods = {
      any = {
        [1] = {
          fn = "function: 0x7f92cbe21540",
          idx = 1,
          method = "all",
          name = "/#1.block_ip.lua",
          type = "filter"
        },
        [2] = {
          fn = "function: 0x7f92cbe1f100",
          idx = 2,
          method = "all",
          name = "/#2.check_user.lua",
          type = "filter"
        },
        [3] = {
          fn = "function: 0x7f92cdd0bc40",
          idx = 3,
          method = "all",
          name = "/$user/#1.block_user.lua",
          type = "filter"
        },
        [4] = {
          fn = "function: 0x7f92cdd15280",
          idx = 4,
          method = "all",
          name = "/$user/posts/#1.extract_id.lua",
          type = "filter"
        },
        [5] = {
          fn = "function: 0x7f92cdd140a0",
          method = "any",
          name = "/$user/posts/@*id.lua",
          type = "handler"
        }
      },
      get = {
        [1] = {
          fn = "function: 0x7f92cbe21540",
          idx = 1,
          method = "all",
          name = "/#1.block_ip.lua",
          type = "filter"
        },
        [2] = {
          fn = "function: 0x7f92cbe1f100",
          idx = 2,
          method = "all",
          name = "/#2.check_user.lua",
          type = "filter"
        },
        [3] = {
          fn = "function: 0x7f92cdd0bc40",
          idx = 3,
          method = "all",
          name = "/$user/#1.block_user.lua",
          type = "filter"
        },
        [4] = {
          fn = "function: 0x7f92cdd15280",
          idx = 4,
          method = "all",
          name = "/$user/posts/#1.extract_id.lua",
          type = "filter"
        },
        [5] = {
          fn = "function: 0x7f92cdd14010",
          method = "get",
          name = "/$user/posts/@*id.lua",
          type = "handler"
        }
      }
    },
    name = "*id",
    rpath = "/:user/posts/*id"
  }
}
```

</details>


## Invoking the handler function

the following code is an example of invoking the handler function.

```lua
local dump = require('dump')
local fsrouter = require('fsrouter')

--- invoke handlers
--- @param r fsrouter - router object
--- @param method string - request method
--- @param pathname string - request pathname
local function invoke_handlers(r, method, pathname)
    method = lower(method)

    local res = {
        headers = {},
        body = {},
    }
    -- lookup route
    local route, err, glob = r:lookup(pathname)
    if err then
        res.status = 500 -- internal server error
        res.error = err
        return res
    elseif not route then
        res.status = 404 -- not found
        return res
    end

    if not next(route.methods) then
        if route.file and method == 'get' then
            -- allow only the GET method for request to file
            res.status = 200 -- ok
            res.file = route.file
            return res
        end
        -- no handler defined for the request method
        res.status = 405 -- method not allowed
        return res
    end

    -- get the list of handler functions
    local handlers = route.methods[method]
    if not mlist then
        -- get the list of handler functions for the any method
        handlers = route.methods.any
        if not handlers then
            -- no handler defined for the request method
            res.status = 405 -- method not allowed
            return res
        end
    end

    -- invoke handlers
    local req = {
        method = method,
        pathname = pathname,
        params = glob,
        uri = route.rpath,
    }
    for i, handler in ipairs(handlers) do
        local ok, err, timeout = handler.fn(req, res)
        if ok or err or timeout then
            if i < #handlers then
                print(('handler chain stopped at #%d: %s'):format(i, handler.name))
            end

            if err then
                -- stop the handler invocation chain if the response is error
                res.status = 500 -- internal server error
                res.error = err
                return res
            elseif timeout then
                -- stop the handler invocation chain if the response is timeout
                res.status = 503 -- service unavailable
                return res
            end

            -- stop the handler invocation chain if the response is ok
            return res
        end
    end
    return res
end

-- create a new router based on the specified directory
local r = fsrouter.new('html')
-- invoke handlers
local res = invoke_handlers('GET', '/foobar/posts/post-id/hello-my-post')
-- reply the response to the client
-- ...
```
