function [en,S] = SWAFadapt_DDDWT(un,dn,S)
% SWAFadapt         Wavelet-transformed Subband Adaptive Filter (WAF)                 
%
% Arguments:
% un                Input signal
% dn                Desired signal
% S                 Adptive filter parameters as defined in WSAFinit.m
% en                History of error signal

M = S.length;                     % Unknown system length (Equivalent adpative filter lenght)
mu = S.step;                      % Step Size
AdaptStart = S.AdaptStart;        % Transient
alpha = S.alpha;                  % Small constant (1e-6)
%H = S.analysis;                   % Analysis filter bank
%F = S.synthesis;                  % Synthesis filter bank

level = S.levels;                 % Wavelet Levels
                    


H = dtfilters('filters2');

len = size(H,1);

F = flipud(H);  
S.analysis = H;
S.synthesis = F; 


L = [M; zeros(level,1)];
for i= 1:level
    L = [floor((L(1)+len-1)/2); L(1:end-1)];
end
S.L = [L(1); L]';
L = S.L;


% Init Arrays
for i= 1:level
          
     
    U.cA{i} = zeros(L(end-i),1); 
    U.cD1{i} = zeros(L(end-i),1);  
    U.cD2{i} = zeros(L(end-i),1);  

    
    Y.cA{i} = zeros(L(end-i),1);
    Y.cD1{i} = zeros(L(end-i),1);
    Y.cD2{i} = zeros(L(end-i),1);
    

    eD{i} = zeros(L(end-i),2);      % Error signa, transformed domain
    eDr{i} = zeros(len,1);          % Error signal, time domain
    delays(i) = 2^i-1;              % Level delay for synthesis   
    w{i} = zeros(L(end-i),2);       % Subband adaptive filter coefficient, initialize to zeros    
    w{i}(1,1) = 1;
    w{i}(1,2) = 1;

    
end 
w{i} = zeros(L(end-i),3);           % Last level has 2 columns, cD and cA

w{i}(1,1) = 1;
w{i}(1,2) = 1;
w{i}(1,3) = 1;


eD{i} = zeros(1,3);                 % Last level has 2 columns, cD and cA
U.tmp = zeros(len,1);
Y.tmp = zeros(len,1);


%pwr = w;
%beta = 1./L(2:end-1);

u = zeros(len,1);                 % Tapped-delay line of input signal (Analysis FB)  
y = zeros(len,1);                 % Tapped-delay line of desired response (Analysis FB)

ITER = length(un);
en = zeros(1,ITER);               % Initialize error sequence to zero


% % ONLY FOR TESTING PURPOSE
% t=0:0.001:1;
% un=20*(t.^2).*(1-t).^4.*cos(12*t.*pi)+sin(2*pi*t*5000)+sin(2*pi*t*150);  

% Testing freezed filters
% w{1} = zeros(L(end-1),2);
% w{1}(1,:) = 1;

for n = 1:ITER    
    u = [un(n); u(1:end-1)];        % Input signal vector contains [u(n),u(n-1),...,u(n-M+1)]'
    y = [dn(n); y(1:end-1)];        % Desired response vector        

    % Analysis Bank
    U.tmp = u;
    Y.tmp = y;
   
    
    for i = 1:level
        if mod(n,2^i) == 0
    
            U.Z = H'*U.tmp;
            U.cA{i} = [U.Z(1); U.cA{i}(1:end-1)];
            U.cD1{i} = [U.Z(2); U.cD1{i}(1:end-1)]; 
            U.cD2{i} = [U.Z(3); U.cD2{i}(1:end-1)]; 
            U.tmp = U.cA{i}(1:len);
                    
            Y.Z = H'*Y.tmp;
            Y.cA{i} = [Y.Z(1); Y.cA{i}(1:end-1)];
            Y.cD1{i} = [Y.Z(2); Y.cD1{i}(1:end-1)]; 
            Y.cD2{i} = [Y.Z(3); Y.cD2{i}(1:end-1)]; 
            Y.tmp = Y.cA{i}(1:len);
             
            if i == level
               
                filt_input =  [U.cA{i}, U.cD1{i},U.cD2{i} ];
                
                eD{i} = Y.Z' - sum((filt_input).*w{i});
                    
                
                if n >= AdaptStart(i)
%                     pwr{i} = beta(i)*pwr{i}+ (1-beta(i))*([U.cA{i},U.cD{i}].*[U.cA{i},U.cD{i}]);
%                     w{i} = w{i} + mu*[U.cA{i},U.cD{i}].*eD{i}./((sum(pwr{i})+alpha)); 
                    w{i} = w{i} + mu*filt_input.*eD{i}./(sum(filt_input.*filt_input)+alpha); 
                    
                  
                    
                end 
            else
                
                
                eD{i} = [eD{i}(2:end,:); [Y.cD1{i}(1), Y.cD2{i}(1)]  - sum([U.cD1{i}(1), U.cD2{i}(1)].*w{i})]; 
                
                
                if n >= AdaptStart(i)
%                     pwr{i} = beta(i)*pwr{i}+ (1-beta(i))*(U.cD{i}.*U.cD{i});
%                     w{i} = w{i} + (mu*eD{i}(end)/((sum(pwr{i}) + alpha)))*U.cD{i};
                    w{i} = w{i} + (mu*eD{i}(end)/(sum([U.cD1{i}(1), U.cD2{i}(1)].*[U.cD1{i}(1), U.cD2{i}(1)])+ alpha))*[U.cD1{i}(1), U.cD2{i}(1)];
                    
                    
                end
            end           
            S.iter{i} = S.iter{i} + 1;                
        end
    end    

    % Synthesis Bank
    for i = level:-1:1     
        if i == level
            if mod(n,2^i) == 0
                eDr{i} = F*eD{i}' + eDr{i};
               
                
            end
        else
            if mod(n,2^i) == 0                
                eDr{i} = F*[eDr{i+1}(1); eD{i}((end-(len-1)*delays(end-i)):end,:)' ] + eDr{i}; %% problema qui cambiare
                eDr{i+1} = [eDr{i+1}(2:end); 0];
                
              
            end            
        end
    end   
    en(n) = eDr{i}(1);
    eDr{i} = [eDr{i}(2:end); 0];        
end

en = en(1:ITER);
S.coeffs = w;
end

%% Full packet 2 layer : TESTING
% % Init Arrays
% for i= 1:level
%     U.cD{i} = zeros(L(end-i),1);    
%     U.cA{i} = zeros(L(end-i),1);    
%     U.cD2{i} = zeros(L(end-i),1);    
%     U.cA2{i} = zeros(L(end-i),1); 
%     Y.cD{i} = zeros(L(end-i),1);
%     Y.cA{i} = zeros(L(end-i),1);
%     Y.cD2{i} = zeros(L(end-i),1);
%     Y.cA2{i} = zeros(L(end-i),1);    
%     eD{i} = zeros(L(end-i),1);      % Error signa, transformed domain
%     eDr{i} = zeros(len,1);          % Error signal, time domain
%     eD2{i} = zeros(L(end-i),1);      
%     eDr2{i} = zeros(len,1);          
%     delays(i) = 2^i-1;              % Level delay for synthesis
%     w{i} = zeros(L(end-i),1);       % Subband adaptive filter coefficient, initialize to zeros
%     w2{i} = zeros(L(end-i),1);
% end 
% w{i} = zeros(L(end-i),2);           % Last level has 2 columns, cD and cA
% eD{i} = zeros(1,2);                 % Last level has 2 columns, cD and cA
% U.tmp = zeros(len,1);
% Y.tmp = zeros(len,1);
% U.Z = zeros(2,1);
% Y.Z = zeros(2,1);
% 
% u = zeros(len,1);                 % Tapped-delay line of input signal (Analysis FB)  
% y = zeros(len,1);                 % Tapped-delay line of desired response (Analysis FB)
% 
% ITER = length(un);
% en = zeros(1,ITER);               % Initialize error sequence to zero
% 
% 
% 
% % % ONLY FOR TESTING PURPOSE
% % t=0:0.001:1;
% % dn=20*(t.^2).*(1-t).^4.*cos(12*t.*pi)+sin(2*pi*t*5000)+sin(2*pi*t*150);  
% 
% % Testing freezed filters
% % w{1} = zeros(L(end-1),2);
% % w{1}(1,:) = 1;
% 
% for n = 1:ITER    
%     u = [un(n); u(1:end-1)];        % Input signal vector contains [u(n),u(n-1),...,u(n-M+1)]'
%     y = [dn(n); y(1:end-1)];        % Desired response vector        
% 
%     % Analysis Bank
%     U.tmp = u;
%     Y.tmp = y;
%     U.tmp2 = u;
%     Y.tmp2 = y;
%     for i = 1:level
%         if mod(n,2^i) == 0
%             U.Z = H'*U.tmp;
%             U.cD{i} = [U.Z(2); U.cD{i}(1:end-1)]; 
%             U.cA{i} = [U.Z(1); U.cA{i}(1:end-1)];
%             U.tmp = U.cA{i}(1:len);
%             U.Z2 = H'*U.tmp2;
%             U.cD2{i} = [U.Z2(2); U.cD2{i}(1:end-1)]; 
%             U.cA2{i} = [U.Z2(1); U.cA2{i}(1:end-1)];
%             U.tmp2 = U.cD2{i}(1:len);
%             
%             Y.Z = H'*Y.tmp;
%             Y.cD{i} = [Y.Z(2); Y.cD{i}(1:end-1)]; 
%             Y.cA{i} = [Y.Z(1); Y.cA{i}(1:end-1)];
%             Y.tmp = Y.cA{i}(1:len);
%             Y.Z2 = H'*Y.tmp2;
%             Y.cD2{i} = [Y.Z2(2); Y.cD2{i}(1:end-1)]; 
%             Y.cA2{i} = [Y.Z2(1); Y.cA2{i}(1:end-1)];
%             Y.tmp2 = Y.cD2{i}(1:len);        
%             
%             if i == level
%                 eD{i} = Y.Z' - sum(([U.cA{i}, U.cD{i}]).*w{i});
%                 eD2{i} = Y.Z2' - sum(([U.cA2{i}, U.cD2{i}]).*w2{i});                
% 
%                 if n >= AdaptStart(i)
%                     w{i} = w{i} + [U.cA{i},U.cD{i}].*(eD{i}./(sum([U.cA{i},U.cD{i}].*[U.cA{i},U.cD{i}])+alpha))*mu; 
%                     w2{i} = w2{i} + [U.cA2{i},U.cD2{i}].*(eD2{i}./(sum([U.cA2{i},U.cD2{i}].*[U.cA2{i},U.cD2{i}])+alpha))*mu; 
%                 end 
%             end           
%             S.iter{i} = S.iter{i} + 1;                
%         end
%     end    
% 
% 
%     % Synthesis Bank
%     for i = level:-1:1
%         if i == level
%             if mod(n,2^i) == 0
%                 eDr{i} = F*eD{i}' + eDr{i};
%                 eDr2{i} = F*eD2{i}' + eDr2{i};
%             end
%         else
%             if mod(n,2^i) == 0                
%                 eDr{i} = F*[eDr{i+1}(1); eDr2{i+1}(1)] + eDr{i};
%                 eDr{i+1} = [eDr{i+1}(2:end); 0];
%                 eDr2{i+1} = [eDr2{i+1}(2:end); 0];
%             end            
%         end
%     end   
%     en(n) = eDr{i}(1);
%     eDr{i} = [eDr{i}(2:end); 0];           
% end
% 
% en = en(1:ITER);
% S.coeffs = [w; w2];
% 
% 
% end

