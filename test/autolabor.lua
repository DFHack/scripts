config = {
    mode = 'fortress',
}

local autolabor = require('plugins.autolabor')

local function loaded()
    expect.true_(autolabor.autolabor_getMode ~= nil,
        'autolabor plugin is not loaded')
end

-- regression: DF releases may add or remove unit_labor enum items, and
-- the engines' static labor data must cover every generated labor type
function test.labor_coverage()
    loaded()
    local gaps = autolabor.autolabor_checkLaborCoverage()
    expect.eq(0, #gaps,
        'uncovered labor types: ' .. table.concat(gaps, ', '))
end

-- regression: DF releases may add or remove job_type enum items; every
-- generated job type must have an entry in the job to labor table
function test.job_coverage()
    loaded()
    local gaps = autolabor.autolabor_checkJobCoverage()
    expect.eq(0, #gaps,
        'uncovered job types: ' .. table.concat(gaps, ', '))
end

function test.mode_api()
    loaded()
    local mode = autolabor.autolabor_getMode()
    expect.true_(mode == 0 or mode == 1 or mode == 2,
        'unexpected mode ' .. tostring(mode))
end

function test.mode_roundtrip()
    loaded()
    local orig = autolabor.autolabor_getMode()
    for _, mode in ipairs{0, 1, 2} do
        autolabor.autolabor_setMode(mode)
        expect.eq(mode, autolabor.autolabor_getMode())
    end
    autolabor.autolabor_setMode(orig)
end

function test.balance_api()
    loaded()
    expect.eq(5, select('#', autolabor.autolabor_getBalanceStops()))
    local orig = autolabor.autolabor_getBalance()
    expect.true_(orig >= 0 and orig < 5,
        'unexpected balance ' .. tostring(orig))
    autolabor.autolabor_setBalance(0)
    expect.eq(0, autolabor.autolabor_getBalance())
    autolabor.autolabor_setBalance(4)
    expect.eq(4, autolabor.autolabor_getBalance())
    autolabor.autolabor_setBalance(orig)
end

function test.idle_reserve_api()
    loaded()
    local orig = autolabor.autolabor_getIdleReserve()
    autolabor.autolabor_setIdleReserve(0)
    expect.eq(0, autolabor.autolabor_getIdleReserve())
    autolabor.autolabor_setIdleReserve(50)
    expect.eq(50, autolabor.autolabor_getIdleReserve())
    autolabor.autolabor_setIdleReserve(orig)
end

function test.starving_jobs()
    loaded()
    local n = autolabor.autolabor_getStarvingJobs()
    expect.true_(type(n) == 'number' and n >= 0)
end
