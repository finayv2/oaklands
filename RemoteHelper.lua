local RemoteHelper = {}

-- Constants
local GUID_PATTERN = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"
local SECRET_SUFFIX = "make_games_dont_cheat"

-- Internal variables
local key
local requiredModule
local cachedRemotes

-- Internal Functions

-- Generates the key based on the player's name and the place version
local function generateKey()
    if key then
        return key
    end
    local playerName = game.Players.LocalPlayer.Name
    local placeVersion = game.PlaceVersion
    key = playerName .. placeVersion .. SECRET_SUFFIX
    return key
end

-- Removes GUID from a string
local function removeGUID(str)
    return str:gsub(GUID_PATTERN, "")
end

-- Reverses the XOR operation without repeating the key
local function reverseHash(hash)
    generateKey() -- Ensure 'key' is generated
    local keyLength = #key
    local chars = {}
    for i = 1, #hash do
        local keyChar = key:byte((i - 1) % keyLength + 1)
        local hashChar = hash:byte(i)
        local xoredByte = bit32.bxor(hashChar, keyChar)
        chars[i] = string.char(xoredByte)
    end
    return table.concat(chars)
end

-- Retrieves the target module and caches it
local function getCachedRemotes()
    if cachedRemotes then
        return cachedRemotes
    end
    local target = game:GetService("ReplicatedFirst").Client
    local success, module = pcall(require, target)
    if not success then
        warn("Failed to require the target module.")
        return nil
    end
    requiredModule = module
    cachedRemotes = requiredModule.CachedRemotes
    return cachedRemotes
end

-- Module Functions

-- Retrieves remote names with cleaned names
function RemoteHelper.get_remote_names()
    local remotes = getCachedRemotes()
    if not remotes then
        return nil
    end

    local remoteMap = {}
    for hashedName, value in pairs(remotes) do
        local cleanName = removeGUID(reverseHash(hashedName))
        remoteMap[cleanName] = value
    end
    return remoteMap
end

-- Returns all remotes
function RemoteHelper.get_all_remotes()
    local remotes = getCachedRemotes()
    if not remotes then
        warn("Failed to retrieve cached remotes.")
        return nil
    end
    return remotes
end

-- Retrieves the key using the specified search logic
function RemoteHelper.get_key()
    if key then
        return key
    end
    if not requiredModule then
        local remotes = getCachedRemotes()
        if not remotes then
            return nil
        end
    end

    local function searchForKeys(func)
        for _, upvalue in ipairs(debug.getupvalues(func)) do
            if type(upvalue) == "string" and upvalue:match(GUID_PATTERN) then
                key = upvalue
                break
            elseif type(upvalue) == "function" then
                searchForKeys(upvalue)
            end
        end
    end

    if type(requiredModule.TellServer) == "function" then
        searchForKeys(requiredModule.TellServer)
    end

    return key
end

-- Searches for a specific remote by name
function RemoteHelper.search_remote_by_name(toSearch)
    local remoteMap = RemoteHelper.get_remote_names()
    if not remoteMap then
        warn("Failed to retrieve remote map.")
        return nil
    end

    return remoteMap[toSearch]
end

-- Searches for a specific remote by value
function RemoteHelper.search_remote_by_value(toSearchValue)
    local remoteMap = RemoteHelper.get_remote_names()
    if not remoteMap then
        warn("Failed to retrieve remote map.")
        return nil
    end

    for name, value in pairs(remoteMap) do
        if value == toSearchValue then
            return name
        end
    end
    return nil
end

return RemoteHelper
