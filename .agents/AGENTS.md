# Custom Agent Rules & Project Best Practices

## Roblox Lua Modular Development & SafeLoad Guidelines

### 1. Avoid False Positive 404 String Matching in `SafeLoad` / `HttpGet`
- **Gotcha**: NEVER use generic `string.find(result, "404")` to check if an HTTP response is a 404 error page. If Lua source code files contain comments, docstrings, or string literals with `"404"` (e.g. `code 404`, `HTTP 404`, `not string.find(data, "404")`), `string.find` will match the source code itself and misinterpret valid Lua scripts as 404 pages!
- **Solution**: Use specific pattern matching or status checks:
  ```lua
  -- DO NOT DO THIS:
  -- if ok and data and not string.find(data, "404") then ... end

  -- DO THIS INSTEAD:
  if ok and type(data) == "string" and #data > 0 and not string.find(data, "404 File not found") then ... end
  ```

### 2. CClosure Method Invocation Syntax in `pcall`
- **Gotcha**: NEVER pass `game.HttpGet` directly as a CClosure argument into `pcall(game.HttpGet, game, url)`. In many Roblox Executors, this throws a metamethod/self-call exception.
- **Solution**: Always wrap `HttpGet` inside an anonymous function closure:
  ```lua
  -- DO NOT DO THIS:
  -- local ok, data = pcall(game.HttpGet, game, url)

  -- DO THIS INSTEAD:
  local ok, data = pcall(function() return game:HttpGet(url) end)
  ```

### 3. Avoid `readfile` Absolute Disk Path Traps in Executors
- **Gotcha**: DO NOT use `isfile("d:/...")` or `readfile("d:/...")` with absolute Windows paths for local dev testing. `isfile` returns `true` because the file exists on Windows disk, but Executor sandboxing blocks `readfile` outside `<Executor>/workspace/`. This causes `SafeLoad` to fail at `readfile` without falling back to Localhost `game:HttpGet`.
- **Solution**: Keep Local Dev `SafeLoad` using `repoUrl = "http://127.0.0.1:8000/<Project>/"` directly with `game:HttpGet`, or require copying files into the Executor's `workspace/` folder.

### 4. GitHub Raw URL Format for Branches with Slashes
- **Gotcha**: When a Git branch contains slashes (e.g. `test/pre-config-manager`), GitHub raw URLs return 404 if formatted as `raw.githubusercontent.com/.../branch/path`.
- **Solution**: Always include `refs/heads/` in raw GitHub URLs for branches containing slashes:
  ```lua
  local rawUrl = "https://raw.githubusercontent.com/chaocauminhlason/scripts-linh-tinh/refs/heads/test/pre-config-manager/Draff/" .. filePath
  ```
