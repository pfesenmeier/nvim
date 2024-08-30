local function islinux()
    -- if fails to expand, it's linux
    return vim.fn.expand("$USERPROFILE") == "$USERPROFILE"
end

local function gethome()
    return vim.fn.expand("$HOME") or vim.fn.expand("USERPROFILE")
end

return {
    islinux = islinux(),
    home = gethome()
}
