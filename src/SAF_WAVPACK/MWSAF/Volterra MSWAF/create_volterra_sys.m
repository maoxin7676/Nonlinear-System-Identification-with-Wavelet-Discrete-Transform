function [Sys_obj] = create_volterra_sys(order, lengths, name )
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here

if order ~= size(lengths,2)
    
    error('order and lengths should have same dimension!');
    
end
Sys_obj.order = order;
Sys_obj.name = name; 

for i = 1:order    
    Sys_obj.M(i) = lengths(i); % append lengths of kernels 
    
    if order > 2
        
        error("not supported order >2");
        
    end
    
    if order ==1
        
    Sys_obj.Responses{i} = rand(lengths(i),1);
    
    else
     tmp = rand(lengths(i),lengths(i));
                           
    Sys_obj.Responses{i} =   (tmp + tmp')/2  ; % if matrix is square this is symmetric 
    end
    
end

end

