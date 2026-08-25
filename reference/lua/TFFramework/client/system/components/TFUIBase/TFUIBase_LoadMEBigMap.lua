local TFUIBase 					= TFUIBase
local TFUI_VERSION_MEEDITOR 	= TFUI_VERSION_MEEDITOR
local TFUI_VERSION_MEEDITOR_GLOBAL_END = TFUI_VERSION_MEEDITOR_GLOBAL_END
local TFUI_VERSION_NEWMEEDITOR 	= TFUI_VERSION_NEWMEEDITOR

function TFUIBase:initMEBigMap(pval, parent)
	if (TFUIBase.version >= TFUI_VERSION_MEEDITOR and TFUIBase.version <= TFUI_VERSION_MEEDITOR_GLOBAL_END) then
		self:initMEBigMap_MEEDITOR(pval, parent)
	elseif TFUIBase.version == TFUI_VERSION_NEWMEEDITOR then
		self:initMEBigMap_NEWMEEDITOR(pval, parent)
	end
end

function TFUIBase:initMEBigMap_MEEDITOR(pval, parent)
	self:initMEPanel(pval, parent)
	local val = pval
	if val['texturePath'] and val['format'] and val['cloumn'] and val['row'] and self.setBigMapTexture then
		self:setBigMapTexture(val['texturePath'], val['format'], val['cloumn'], val['row'])
	end
end

function TFUIBase:initMEBigMap_NEWMEEDITOR(pval, parent)
	self:initMEPanel(pval, parent)
	local val = pval
	if val['texturePath'] and val['format'] and val['cloumn'] and val['row'] and self.setBigMapTexture then
		self:setBigMapTexture(val['texturePath'], val['format'], val['cloumn'], val['row'])
	end
end
