local addon, private = ...
local Chatter = LibStub("AceAddon-3.0"):GetAddon(addon)
local mod = Chatter:NewModule("Channel Names", "AceHook-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon)
mod.modName = L["Channel Names"]

local gsub = _G.string.gsub
local find = _G.string.find
local pairs = _G.pairs
local loadstring = _G.loadstring
local tostring = _G.tostring
local GetChannelList = _G.GetChannelList
local select = _G.select

local empty_tag = L["$$EMPTY$$"];

local defaults = {
    profile = {
        channels = {
            ["CHAT_MSG_GUILD"] = "[G]",
            ["CHAT_MSG_OFFICER"] = "[O]",
            ["CHAT_MSG_PARTY"] = "[P]",
            ["CHAT_MSG_PARTY_LEADER"] = "[PL]",
            ["CHAT_MSG_RAID"] = "[R]",
            ["CHAT_MSG_RAID_LEADER"] = "[RL]",
            ["CHAT_MSG_RAID_WARNING"] = "[RW]",
            ["CHAT_MSG_INSTANCE_CHAT"] = "[I]",
            ["CHAT_MSG_INSTANCE_CHAT_LEADER"] = "[IL]",

            -- Not localized here intentionally
            ["Whisper From"] = "[W:From]",
            ["Whisper To"] = "[W:To]",
            ["BN Whisper From"] = "[BN:From]",
            ["BN Whisper To"] = "[BN:To]",
            ["away BN Whisper To"] = "<Away>[BN:To]",
            ["busy BN Whisper To"] = "<Busy>[BN:To]",

            ["General"] = "GRN",
            ["Trade"] = "TRD",
            ["LocalDefense"] = "LDF"
        },
        addSpace = true
    }
}
local channels

local options = {
    splitter = {
        type = "header",
        name = L["Custom Channels"]
    },
    addSpace = {
        type = "toggle",
        name = L["Add space after channels"],
        desc = L["Add space after channels"],
        get = function() return mod.db.profile.addSpace end,
        set = function(info, v) mod.db.profile.addSpace = v end
    }
}

local serverChannels = {}
local function excludeChannels(...)
    for i = 1, select("#", ...), 3 do
        local id, name, disabled = select(i, ...)
        if name then
            serverChannels[tostring(name)] = true
        end
    end
end

local functions = {}

local function normalizeChannel(channel)
    if channel == "INSTANCE_CHAT" then return "CHAT_MSG_INSTANCE_CHAT" end
    if channel == "INSTANCE_CHAT_LEADER" then return "CHAT_MSG_INSTANCE_CHAT_LEADER" end
    return channel
end
local function addChannel(name)
    options[name:gsub(" ", "_")] = {
        type = "input",
        name = name,
        desc = L["Replace this channel name with..."],
        order = name:lower() == name and 101 or 98,
        get = function()
            local v = mod.db.profile.channels[name]
            return v == "" and " " or v
        end,
        set = function(info, v)
            mod.db.profile.channels[name] = #v > 0 and v or nil
            if v:match("^function%(") then
                functions[name] = loadstring("return " .. v)()
            else
                functions[name] = nil
            end
        end
    }
end

function mod:OnInitialize()
    self.db = Chatter.db:RegisterNamespace("ChannelNames", defaults)
    self.db.profile.customChannels = nil
    for k, _ in pairs(self.db.profile.channels) do
        addChannel(k)
    end
    excludeChannels(GetChannelList())
    for k, v in pairs(serverChannels) do
        addChannel(k)
    end
    self:AddCustomChannels(GetChannelList())

    for k, v in pairs(self.db.profile.channels) do
        if v:match("^function%(") then
            functions[k] = loadstring("return " .. v)()
        end
    end
end
function mod:AddCustomChannels(...)
    for i = 1, select("#", ...), 3 do
        local id, name = select(i, ...)
        if not serverChannels[name] and not options[name:gsub(" ", "_")] then
            options[name:gsub(" ", "_")] = {
                type = "input",
                name = name,
                desc = L["Replace this channel name with..."],
                order = id <= 4 and 98 or 101,
                get = function()
                    local safeName = tostring(name or "")
                    local v = self.db.profile.channels[safeName:lower()]
                    return v == "" and " " or v
                end,
                set = function(info, v)
                    self.db.profile.channels[name:lower()] = #v > 0 and v or nil
                    if v:match("^function%(") then
                        functions[name:lower()] = loadstring("return " .. v)()
                    end
                end
            }
        end
    end
end

function mod:Decorate(frame)
    self:RawHook(frame, "AddMessage", true)
end
function mod:OnEnable()
    channels = self.db.profile.channels
    self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf ~= COMBATLOG then
            self:RawHook(cf, "AddMessage", true)
        end
    end
    if self.TempChatFrames then
        for index, name in ipairs(self.TempChatFrames) do
            local cf = _G[name]
            if cf then
                self:RawHook(cf, "AddMessage", true)
            end
        end
    end
end

function mod:CHAT_MSG_CHANNEL_NOTICE()
    self:AddCustomChannels(GetChannelList())
end
local function replaceChannel(origChannel, msg, num, channel)
    local safeChannel = normalizeChannel(channel)
    local safeMsg = tostring(msg or "")

    local f = functions[safeChannel] or functions[safeChannel:lower()]
    local newChannelName = f and f(safeChannel) or channels[safeChannel] or channels[safeChannel:lower()] or safeMsg
    if newChannelName == empty_tag then return "" end

    return ("|Hchannel:%s|h%s|h%s"):format(tostring(origChannel or ""), tostring(newChannelName or ""), mod.db.profile.addSpace and " " or "")
end

local function replaceChannelRW(msg, channel)
    local safeChannel = normalizeChannel(channel)
    local safeMsg = tostring(msg or "")
    local f = functions[safeChannel] or functions[safeChannel:lower()]
    local newChannelName = f and f(safeChannel) or channels[safeChannel] or channels[safeChannel:lower()] or safeMsg
    return tostring(newChannelName or "") .. (mod.db.profile.addSpace and " " or "")
end
function mod:AddMessage(frame, text, ...)
    if not text then
        return self.hooks[frame].AddMessage(frame, text, ...)
    end
    -- removed the start of check, since blizz timestamps inject themselves in front of the line
    if (CHAT_TIMESTAMP_FORMAT) then
        text = gsub(text, "|Hchannel:(%S-)|h(%[([%d. ]*)([^%]]+)%])|h ", replaceChannel)
        text = gsub(text, "(%[(" .. L["Raid Warning"] .. ")%]) ", replaceChannelRW)
    else
        text = gsub(text, "^|Hchannel:(%S-)|h(%[([%d. ]*)([^%]]+)%])|h ", replaceChannel)
        text = gsub(text, "^(%[(" .. L["Raid Warning"] .. ")%]) ", replaceChannelRW)
    end
    if mod.db.profile.channels then
        text = gsub(text, L["To (|Hplayer.-|h):"], function(name)
            local prefix = mod.db.profile.channels["Whisper To"] or "[W:From]"
            local space = mod.db.profile.addSpace and " " or ""
            return prefix .. space .. name .. ":"
        end)

        text = gsub(text, L["(|Hplayer.-|h) whispers:"], function(name)
            local prefix = mod.db.profile.channels["Whisper From"] or "[W:To]"
            local space = mod.db.profile.addSpace and " " or ""
            return prefix .. space .. name .. ":"
        end)

        text = gsub(text, L["To (|HBNplayer.-|h):"], function(name)
            local prefix = mod.db.profile.channels["BN Whisper To"] or "[BN:From]"
            local space = mod.db.profile.addSpace and " " or ""
            return prefix .. space .. name .. ":"
        end)

        text = gsub(text, L["To <Away>(|HBNplayer.-|h):"], function(name)
            local prefix = mod.db.profile.channels["away BN Whisper To"] or "[BN:To]"
            local space = mod.db.profile.addSpace and " " or ""
            return prefix .. space .. name .. ":"
        end)

        text = gsub(text, L["To <Busy>(|HBNplayer.-|h):"], function(name)
            local prefix = mod.db.profile.channels["busy BN Whisper To"] or "<Away>[BN:To]"
            local space = mod.db.profile.addSpace and " " or ""
            return prefix .. space .. name .. ":"
        end)

        text = gsub(text, L["(|HBNplayer.-|h): whispers:"], function(name)
            local prefix = mod.db.profile.channels["BN Whisper From"] or "<Busy>[BN:To]"
            local space = mod.db.profile.addSpace and " " or ""
            return prefix .. space .. name .. ":"
        end)

        -- General, Trade, and LocalDefense replacements
        text = gsub(text, "(%[1%. General %- .-%])(.)", (mod.db.profile.channels["General"] or "GRN") .. "%2", 1)
        text = gsub(text, "(%[2%. Trade %- City%])(.)", (mod.db.profile.channels["Trade"] or "TRD") .. "%2", 1)
        text = gsub(text, "(%[3%. LocalDefense %- .-%])(.)", (mod.db.profile.channels["LocalDefense"] or "LDF") .. "%2", 1)
    end
    return self.hooks[frame].AddMessage(frame, text, ...)
end
function mod:GetOptions()
    return options
end

function mod:Info()
    return L["Enables you to replace channel names with your own names. You can use '%s' to force an empty string."]:format(empty_tag)
end

mod.funcs = functions
