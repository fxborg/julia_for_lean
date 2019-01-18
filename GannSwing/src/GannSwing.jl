module GannSwing

using TimeSeries
struct BarInfo
    Id::Int
    High::Float64
    Low::Float64
    Close::Float64
    Weight::Int
end



mutable struct GannSwingObj
    parm::Int
    dir::Int
    bars::Array{BarInfo,1}
end
GannSwingObj(param::Int)=GannSwingObj(param,1,BarInfo[])

function get_ohlc(ta::TimeArray{Float64,2},i) 
   (values(ta[:Open][i])[1],values(ta[:High][i])[1],values(ta[:Low][i])[1], values(ta[:Close][i])[1])
end

function _check_downswing(bars::Array{BarInfo,1}, i::Int, h::Float64, l::Float64, c::Float64,limit::Int )::Symbol
    sz=length(bars)
    if(sz==0) return :FirstBar end
    if(bars[end].High >= h && bars[end].Low <= l) return :InSideBar end
    # continue trend
    if(bars[1].Low > l)
        if(sz==1 && bars[1].High < c)  return :SpikeBar end
        return :TrendBar
    end
    # revese trigger
    if(bars[end].High < h)
        if (sz + bars[1].Weight >= limit) return :SignalBar end
    end
    return :ReverseBar  
end

function _check_upswing(bars::Array{BarInfo,1}, i::Int, h::Float64, l::Float64, c::Float64,limit::Int )::Symbol

    sz=length(bars)
    if(sz==0) return :FirstBar end
    if(bars[end].High >= h && bars[end].Low <= l) return :InSideBar end
    # continue trend
    if(bars[1].High < h)
        if(sz==1 && bars[1].Low > c)  return :SpikeBar end
        return :TrendBar
    end

    # revese trigger
    if(bars[end].Low > l)
        if (sz + bars[1].Weight >= limit) return :SignalBar end
    end
    return :ReverseBar
end

function _gann_swing(dir::Int,bars::Array{BarInfo,1}, i::Int, h::Float64, l::Float64, c::Float64, limit::Int)::Tuple{Bool,Int,Float64}

    id = i    
    val = 0.0
    chk = false

    if dir == 1
        ans = _check_upswing(bars, i, h, l, c ,limit)
    else
        ans = _check_downswing(bars, i, h, l, c ,limit)
    end 
    if(ans == :SignalBar)
        chk = true
        id = bars[1].Id
        val = (dir==1) ? bars[1].High : bars[1].Low
    end
    if(ans == :TrendBar || ans == :SpikeBar || ans == :SignalBar)
        resize!(bars,0)
    end        
    if(ans != :InSideBar && ans != :SignalBar)
        w = (ans == :SpikeBar) ? 1 : 0    
        push!(bars, BarInfo(i,h,l,c,w))
    end
    (chk,id,val)    
end

function calculate(gann::GannSwingObj,ta::TimeArray{Float64,2},i::Int)::Tuple{Int,Array{Int,1},Array{Float64,1}}
    g_y=Float64[]
    g_x=Int[]
    if abs(gann.dir) != 1 gann.dir = 1 end

    (o,h,l,c)=get_ohlc(ta,i)
    (chk,id,val) = _gann_swing(gann.dir, gann.bars, i, h, l ,c,gann.parm)
    if (chk)
        gann.dir=-gann.dir
        j=id
        push!(g_y,val)
        push!(g_x,id)
        added=false
        while(j<=i)
            if !added
                (o,h,l,c)=get_ohlc(ta,j)
                (chk2,id2,val2) = _gann_swing(gann.dir, gann.bars, j, h, l ,c,gann.parm)
                if(chk2)
                  push!(g_y,val2)
                  push!(g_x,id2)
                  gann.dir=-gann.dir
                  added=true
                end
            end
            j+=1
        end
    end
    i+=1
    (gann.dir, g_x, g_y)
end
export GannSwing    
export calculate

end # module
