
if GetResourceState('qbx_core') ~= 'started' then return end

Framework = {}
Framework.Name = 'QBox'

function Framework.GetPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

function Framework.HasJobAccess(src, jobTbl)
    if not jobTbl then return true end
    -- Check against all groups
    return exports.qbx_core:HasGroup(src, jobTbl)
    -- Check against current job / gang
    --return exports.qbx_core:HasPrimaryGroup(src, jobTbl)
end

