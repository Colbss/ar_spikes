if GetResourceState('qbx_core') ~= 'started' then return end

Framework = {}
Framework.Name = 'QBox'

function Framework.HasJobAccess(jobTbl)
    if not jobTbl then return true end
    -- Check against all groups
    return exports.qbx_core:HasGroup(jobTbl)
    -- Check against current job / gang
    --return exports.qbx_core:HasPrimaryGroup(jobTbl)
end