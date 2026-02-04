local addon, private = ...
local Chatter = LibStub("AceAddon-3.0"):GetAddon(addon)
local mod = Chatter:NewModule("Invite Links", "AceHook-3.0","AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon)

mod.modName = L["Invite Links"]
mod.toggleLabel = L["Invite Links"]

local gsub = _G.string.gsub
local ipairs = _G.ipairs
local fmt = _G.string.format
local sub = _G.string.sub
local InviteUnit = C_PartyInfo.InviteUnit
local next = _G.next
local type = _G.type
local IsAltKeyDown = _G.IsAltKeyDown
local match = _G.string.match

local options = {
	addWord = {
		type = "input",
		name = L["Add Word"],
		desc = L["Add word to your invite trigger list"],
		get = function() end,
		set = function(info, v)
			mod.db.profile.words[v:lower()] = v
		end
	},
	removeWord = {
		type = "select",
		name = L["Remove Word"],
		desc = L["Remove a word from your invite trigger list"],
		get = function() end,
		set = function(info, v)
			mod.db.profile.words[v:lower()] = nil
		end,
		values = function() return mod.db.profile.words end,
		confirm = function(info, v) return (L["Remove this word from your trigger list?"]) end
	},
	altClick = {
		type = "toggle",
		name = L["Alt-click name to invite"],
		width = "double",
		desc = L["Lets you alt-click player names to invite them to your party."],
		get = function() return mod.db.profile.altClickToinvite end,
		set = function(i, v) mod.db.profile.altClickToinvite = v end
	}
}

local defaults = {
	profile = {
		words = {},
		altClickToInvite = true
	}
}

local words
local valid_events = {
	CHAT_MSG_SAY = true,
	CHAT_MSG_CHANNEL = true,
	CHAT_MSG_WHISPER = true,
	CHAT_MSG_OFFICER = true,
	CHAT_MSG_GUILD = true
}

function mod:OnInitialize()
	self.db = Chatter.db:RegisterNamespace(self:GetName(), defaults)
end

function mod:Decorate(frame)
	if not self:IsHooked(frame, "AddMessage") then
		self:RawHook(frame, "AddMessage", true)
	end
end

local _, chatEvent, chatEventTarget

-- 2025 修正：移除對 ChatFrame_MessageEventHandler 的直接 Hook，改用事件監聽
function mod:OnEnable()
	words = self.db.profile.words
	if not next(words) then
		words[L["invite"]] = L["invite"]
		words[L["inv"]] = L["inv"]
	end
	
	for i = 1, NUM_CHAT_WINDOWS do
		local cf = _G["ChatFrame" .. i]
		if cf and cf ~= COMBATLOG then
			if not self:IsHooked(cf, "AddMessage") then
				self:RawHook(cf, "AddMessage", true)
			end
		end
	end

	-- 安全 Hook HyperlinkShow
	if _G.ChatFrame_OnHyperlinkShow then
		self:RawHook("ChatFrame_OnHyperlinkShow", true)
	end

	-- 監聽聊天事件以獲取當前發言者，取代對 EventHandler 的 Hook
	self:RegisterEvent("CHAT_MSG_SAY", "RecordTarget")
	self:RegisterEvent("CHAT_MSG_WHISPER", "RecordTarget")
	self:RegisterEvent("CHAT_MSG_GUILD", "RecordTarget")
	self:RegisterEvent("CHAT_MSG_CHANNEL", "RecordTarget")
end

function mod:RecordTarget(event, msg, sender)
	chatEvent = event
	chatEventTarget = sender
end

local style = "|cffffffff|Hinvite:%s|h[%s]|h|r"

local function addLinks(m, t, p)
	if chatEventTarget and words[t:lower()] and p ~= "_" then
		t = fmt(style, chatEventTarget, t)
		return t .. p
	end
	return m
end

function mod:AddMessage(frame, text, ...)
	if not text then
		return self.hooks[frame].AddMessage(frame, text, ...)
	end
	if valid_events[chatEvent] and type(chatEventTarget) == "string" then
		text = gsub(text, "((%w+)(.?))", addLinks)
	end

	return self.hooks[frame].AddMessage(frame, text, ...)
end

function mod:ChatFrame_OnHyperlinkShow(frame, linkData, link, button)
	local linkType = sub(linkData, 1, 6)

	if IsAltKeyDown() and linkType == "player" and self.db.profile.altClickToInvite then
		local name = match(linkData, "player:([^:]+)")
		if name then InviteUnit(name) end
		return nil
	elseif linkType == "invite" then
		local name = sub(linkData, 8)
		if name then InviteUnit(name) end
		return nil
	else
		return self.hooks["ChatFrame_OnHyperlinkShow"](frame, linkData, link, button)
	end
end

function mod:Info()
	return L["Gives you more flexibility in how you invite people to your group."]
end

function mod:GetOptions()
	return options
end

