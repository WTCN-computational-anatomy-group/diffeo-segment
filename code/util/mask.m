function f = mask(f,msk)
f(~isfinite(f)) = 0;
f = f.*msk;
end
%==========================================================================