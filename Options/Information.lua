local addon = select(2, ...)
local E = addon[3]

-- The version line sits above the first header: it is the page title in
-- EllesmereUI's own Information pages too, and a header above a single button
-- only adds a word to read.
addon.RegisterOptionBuilder("information", function(parent, y)
	local L = addon.L
	local Widgets = EllesmereUI.Widgets
	local _, h

	local devVersion = addon.GetDevelopmentVersion and addon.GetDevelopmentVersion()
	if devVersion then
		_, h = Widgets:Button(parent, L("Development Version: %s"):format(tostring(devVersion)), y, function() end)
		y = y - h
	end

	_, h = Widgets:SectionHeader(parent, "LINKS", y); y = y - h

	_, h = Widgets:Button(parent, "GitHub Repository", y, function()
		if E.StaticPopup_Show then
			E:StaticPopup_Show("WINDTOOLS_EDITBOX", nil, nil, "https://github.com/wind-addons/ElvUI_WindTools")
		end
	end); y = y - h

	_, h = Widgets:Button(parent, "Report Issue", y, function()
		if E.StaticPopup_Show then
			E:StaticPopup_Show("WINDTOOLS_EDITBOX", nil, nil, "https://github.com/wind-addons/ElvUI_WindTools/issues")
		end
	end); y = y - h

	_, h = Widgets:Button(parent, "Wiki", y, function()
		if E.StaticPopup_Show then
			E:StaticPopup_Show("WINDTOOLS_EDITBOX", nil, nil, "https://github.com/wind-addons/ElvUI_WindTools/wiki")
		end
	end); y = y - h

	_, h = Widgets:SectionHeader(parent, "CREDITS", y); y = y - h

	_, h = Widgets:Button(parent, "Author: fang2hou", y, function() end); y = y - h
	_, h = Widgets:Button(parent, "Author: XanaHopper", y, function() end); y = y - h

	return y
end)
