%# Copyright (C) 2015 Schinzilord <schinzilord@octarisk.com>
%#
%# This program is free software; you can redistribute it and/or modify it under
%# the terms of the GNU General Public License as published by the Free Software
%# Foundation; either version 3 of the License, or (at your option) any later
%# version.
%#
%# This program is distributed in the hope that it will be useful, but WITHOUT
%# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
%# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
%# details.

%# -*- texinfo -*-
%# @deftypefn {Function File} {[@var{ret_dates} @var{ret_values} @var{accrued_interest}] =} rollout_structured_cashflows (@var{valuation_date},  @var{value_type}, @var{instrument}, @var{ref_curve}, @var{surface}, @var{vriskfactor})
%#
%# Compute the dates and values of cash flows (interest and principal and 
%# accrued interests and last coupon date for fixed rate bonds, 
%# floating rate notes, amortizing bonds, zero coupon bonds and 
%# structured products like caps and floors.@*
%# For FAB, ref_curve is used as prepayment curve, surface for PSA factors,
%# riskfactor for IR Curve shock extraction
%#
%# @seealso{timefactor, discount_factor, get_forward_rate, interpolate_curve}
%# @end deftypefn

function [ret_dates ret_values ret_interest_values ret_principal_values ...
                                    accrued_interest last_coupon_date] = ...
                    rollout_structured_cashflows(valuation_date, value_type, ...
                    instrument, ref_curve, surface,riskfactor)

%TODO: introduce prepayment type 'default'

% Parse bond struct
if nargin < 3 || nargin > 6
    print_usage ();
 end

if (ischar(valuation_date))
    valuation_date = datenum(valuation_date); 
end

if nargin > 3 
% get curve variables:
    tmp_nodes    = ref_curve.get('nodes');
    tmp_rates    = ref_curve.getValue(value_type);

% Get interpolation method and other curve related attributes
    method_interpolation = ref_curve.get('method_interpolation');
    basis_curve     = ref_curve.get('basis');
    comp_type_curve = ref_curve.get('compounding_type');
    comp_freq_curve = ref_curve.get('compounding_freq');
 end
                                
% --- Checking object field items --- 
    compounding_type = instrument.compounding_type;
    if (strcmp(instrument.issue_date,'01-Jan-1900'))
        issue_date = datestr(valuation_date);
    else
        issue_date = instrument.issue_date;
    end
    day_count_convention    = instrument.day_count_convention;
    dcc                     = instrument.basis;
    coupon_rate             = instrument.coupon_rate;
    coupon_generation_method = instrument.coupon_generation_method; 
    notional_at_start       = instrument.notional_at_start; 
    notional_at_end         = instrument.notional_at_end; 
    business_day_rule       = instrument.business_day_rule;
    business_day_direction  = instrument.business_day_direction;
    enable_business_day_rule = instrument.enable_business_day_rule;
    long_first_period       = instrument.long_first_period;
    long_last_period        = instrument.long_last_period;
    spread                  = instrument.spread;
    in_arrears_flag         = instrument.in_arrears;

% --- Checking mandatory structure field items --- 

    type = instrument.sub_type;
    if (  strcmpi(type,'ZCB') )
        coupon_generation_method = 'zero';
        instrument.term = '0';
    elseif ( strcmpi(type,'FRN') || strcmpi(type,'SWAP_FLOATING') || strcmpi(type,'CAP') || strcmpi(type,'FLOOR'))
            last_reset_rate = instrument.last_reset_rate;
    elseif ( strcmpi(type,'FAB'))
            fixed_annuity_flag = instrument.fixed_annuity;
            use_principal_pmt_flag = instrument.use_principal_pmt;
    end
    notional = instrument.notional;
    term = instrument.term;
    compounding_freq = instrument.compounding_freq;
    maturity_date = instrument.maturity_date;

% check for existing interest rate curve for FRN
if (nargin < 2 && strcmp(type,'FRN') == 1)
    error('Too few arguments. No existing IR curve for type FRN.');
end

if (nargin < 2 && strcmp(type,'SWAP_FLOATING') == 1)
    error('Too few arguments. No existing IR curve for type FRN.');
end

if ( datenum(issue_date) > datenum(maturity_date ))
    error('Error: Issue date later than maturity date');
end

% ------------------------------------------------------------------------------
% Start Calculation:
issuevec = datevec(issue_date);
todayvec = datevec(valuation_date);
matvec = datevec(maturity_date);

% floor forward rate at 0.000001:
floor_flag = false;
% cashflow rollout: method backwards
if ( strcmp(coupon_generation_method,'backward') == 1 )
cf_date = matvec;
cf_dates = cf_date;

while datenum(cf_date) >= datenum(issue_date)
    cf_year = cf_date(:,1);
    cf_month = cf_date(:,2);
    cf_day  = cf_date(:,3);
    cf_original_day  = matvec(:,3);
    
    % depending on frequency, adjust year, month or day
    % rollout for annual (compounding frequency = 1 payment per year)
    if ( term == 12)
        new_cf_year = cf_year - 1;
        new_cf_month = cf_month;
        new_cf_day = cf_day;
        comp_freq = 1;
    % rollout for annual 365 days (compounding frequency = 1 payment per year)
    elseif ( term == 365)
        new_cf_date = datenum(cf_date)-365;
        new_cf_date = datevec(new_cf_date);
        new_cf_year = new_cf_date(:,1);
        new_cf_month = new_cf_date(:,2);
        new_cf_day = new_cf_date(:,3);    
        comp_freq = 1;
    % rollout for semi-annual (compounding frequency = 2 payments per year)
    elseif ( term == 6)
        new_cf_year = cf_year;
        new_cf_month = cf_month - 6;
        if ( new_cf_month <= 0 )
            new_cf_month = cf_month + 6;
            new_cf_year = cf_year - 1;
        end
        comp_freq = 2;
        % error checking for end of month
        new_cf_day = check_day(new_cf_year,new_cf_month,cf_original_day);
    % rollout for quarter (compounding frequency = 4 payments per year)
    elseif ( term == 3)
        new_cf_year = cf_year;
        new_cf_month = cf_month - 3;
        if ( new_cf_month <= 0 )
            new_cf_month = cf_month + 9;
            new_cf_year = cf_year - 1;
        end
        comp_freq = 4;
        % error checking for end of month
        new_cf_day = check_day(new_cf_year,new_cf_month,cf_original_day);
    % rollout for monthly (compounding frequency = 12 payments per year)
    elseif ( term == 1)
        cf_day = cf_original_day;
        new_cf_year = cf_year;
        new_cf_month = cf_month - 1;
        if ( new_cf_month <= 0 )
            new_cf_month = cf_month + 11;
            new_cf_year = cf_year - 1;
        end
        comp_freq = 12;
        % error checking for end of month
        new_cf_day = check_day(new_cf_year,new_cf_month,cf_original_day);
    end
        
    cf_date = [new_cf_year, new_cf_month, new_cf_day, 0, 0, 0];
    if datenum(cf_date) >= datenum(issue_date) 
        cf_dates = [cf_dates ; cf_date];
    end
end % end coupon generation backward


% cashflow rollout: method forward
elseif ( strcmp(coupon_generation_method,'forward') == 1 )
cf_date = issuevec;
cf_dates = cf_date;

while datenum(cf_date) <= datenum(maturity_date)
    cf_year = cf_date(:,1);
    cf_month = cf_date(:,2);
    cf_day  = cf_date(:,3);
    cf_original_day  = issuevec(:,3);
    
    % depending on frequency, adjust year, month or day
    % rollout for annual (compounding frequency = 1 payment per year)
    if ( term == 12)
        new_cf_year = cf_year + 1;
        new_cf_month = cf_month;
        new_cf_day = cf_day;
        comp_freq = 1;
    % rollout for annual 365 days (compounding frequency = 1 payment per year)
    elseif ( term == 365)
        new_cf_date = datenum(cf_date) + 365;
        new_cf_date = datevec(new_cf_date);
        new_cf_year = new_cf_date(:,1);
        new_cf_month = new_cf_date(:,2);
        new_cf_day = new_cf_date(:,3);   
        comp_freq = 1;
    % rollout for semi-annual (compounding frequency = 2 payments per year)
    elseif ( term == 6)
        new_cf_year = cf_year;
        new_cf_month = cf_month + 6;
        if ( new_cf_month >= 13 )
            new_cf_month = cf_month - 6;
            new_cf_year = cf_year + 1;
        end
        comp_freq = 2;
        % error checking for end of month
        new_cf_day = check_day(new_cf_year,new_cf_month,cf_original_day);
    % rollout for quarter (compounding frequency = 4 payments per year)
    elseif ( term == 3)
        new_cf_year = cf_year;
        new_cf_month = cf_month + 3;
        if ( new_cf_month >= 13 )
            new_cf_month = cf_month - 9;
            new_cf_year = cf_year + 1;
        end
        comp_freq = 4;
        % error checking for end of month
        new_cf_day = check_day(new_cf_year,new_cf_month,cf_original_day);
    % rollout for monthly (compounding frequency = 12 payments per year)
    elseif ( term == 1)
        cf_day = cf_original_day;
        new_cf_year = cf_year;
        new_cf_month = cf_month + 1;
        if ( new_cf_month >= 13 )
            new_cf_month = cf_month - 11;
            new_cf_year = cf_year + 1;
        end
        comp_freq = 12;
        % error checking for end of month
        new_cf_day = check_day(new_cf_year,new_cf_month,cf_original_day);
    else
        error('rollout_cashflows_oop: unknown term >>%s<<',any2str(term));
    end
        
    cf_date = [new_cf_year, new_cf_month, new_cf_day, 0, 0, 0];
    if datenum(cf_date) <= datenum(maturity_date) 
        cf_dates = [cf_dates ; cf_date];
    end
end        % end coupon generation forward

%-------------------------------------------------------------------------------
% cashflow rollout: method zero
elseif ( strcmp(coupon_generation_method,'zero') == 1 )
    % rollout for zero coupon bonds -> just one cashflow at maturity
        cf_dates = [issuevec ; matvec];
end 
%-------------------------------------------------------------------------------    

% Sort CF Dates:
cf_dates = datevec(sort(datenum(cf_dates)));

%-------------------------------------------------------------------------------
% Adjust first and last coupon period to implement issue date:
if (long_first_period == true)
    if ( datenum(cf_dates(1,:)) > datenum(issue_date) )
        cf_dates(1,:) = issuevec;
    end
else
    if ( datenum(cf_dates(1,:)) > datenum(issue_date) )
        cf_dates = [issuevec;cf_dates];
    end    
end
if (long_last_period == true)
    if ( datenum(cf_dates(rows(cf_dates),:)) < datenum(maturity_date) )
        cf_dates(rows(cf_dates),:) = matvec;
    end
else
    if ( datenum(cf_dates(rows(cf_dates),:)) < datenum(maturity_date) )
        cf_dates = [cf_dates;matvec];
    end
end
cf_business_dates = datevec(busdate(datenum(cf_dates)-1 + business_day_rule, ...
                                    business_day_direction));
%-------------------------------------------------------------------------------


%-------------------------------------------------------------------------------
% ############   Calculate Cash Flow values depending on type   ################   
%
% Type FRB: Calculate CF Values for all CF Periods
if ( strcmp(type,'FRB') == 1 || strcmp(type,'SWAP_FIXED') == 1 )
    cf_datesnum = datenum(cf_dates);
    %cf_datesnum = cf_datesnum((cf_datesnum-today)>0)
    d1 = cf_datesnum(1:length(cf_datesnum)-1);
    d2 = cf_datesnum(2:length(cf_datesnum));
    % preallocate memory
    cf_values = zeros(1,length(d1));
    cf_principal = zeros(1,length(d1));
    % calculate all cash flows
    for ii = 1: 1 : length(d2)
        cf_values(ii) = ((1 ./ discount_factor(d1(ii), d2(ii), coupon_rate, ...
                                            compounding_type, dcc, ...
                                            compounding_freq)) - 1) .* notional;
    end
    ret_values = cf_values;
    cf_interest = cf_values;
    % Add notional payments
    if ( notional_at_start == 1)    % At notional payment at start
        ret_values(:,1) = ret_values(:,1) - notional;     
        cf_principal(:,1) = - notional;
    end
    if ( notional_at_end == true) % Add notional payment at end to cf vector:
        ret_values(:,end) = ret_values(:,end) + notional;
        cf_principal(:,end) = notional;
    end
    
% Type FRN: Calculate CF Values for all CF Periods with forward rates based on 
%           spot rate defined 
elseif ( strcmpi(type,'FRN') || strcmpi(type,'SWAP_FLOATING') || strcmpi(type,'CAP') || strcmpi(type,'FLOOR'))
    cf_datesnum = datenum(cf_dates);
    %cf_datesnum = cf_datesnum((cf_datesnum-valuation_date)>0);
    d1 = cf_datesnum(1:length(cf_datesnum)-1);
    d2 = cf_datesnum(2:length(cf_datesnum));
    notvec = zeros(1,length(d1));
    notvec(length(notvec)) = 1;
    cf_values = zeros(rows(tmp_rates),length(d1));
    cf_principal = zeros(rows(tmp_rates),length(d1));
    
    for ii = 1 : 1 : length(d1)
        % convert dates into years from valuation date with timefactor
        [tf dip dib] = timefactor (d1(ii), d2(ii), dcc);
        t1 = (d1(ii) - valuation_date);
        t2 = (d2(ii) - valuation_date);
        if ( t1 >= 0 && t2 >= t1 )        % for future cash flows use forward rates
            % get forward rate from provided curve
            forward_rate_curve = get_forward_rate(tmp_nodes,tmp_rates, ...
                        t1,t2-t1,compounding_type,method_interpolation, ...
                        compounding_freq, dcc, valuation_date, ...
                        comp_type_curve, basis_curve, comp_freq_curve,floor_flag);
            % calculate final floating cash flows
            if (strcmpi(type,'CAP') || strcmpi(type,'FLOOR'))
                % call function to calculate probability weighted forward rate
                X = instrument.strike;  % get from strike curve ?!?
                % calculate timefactor of forward start date
                tf_fsd = timefactor (valuation_date, valuation_date + t1, dcc);
                % calculate moneyness 
                if (instrument.CapFlag == true)
                    moneyness_exponent = 1;
                else
                    moneyness_exponent = -1;
                end
                moneyness = (forward_rate_curve ./ X) .^ moneyness_exponent;
                % get volatility according to moneyness and term
                tenor   = t1; % days until foward start date
                term    = t2 - t1; % days of caplet / floorlet
                sigma = calcVolaShock(value_type,instrument,surface, ...
                            riskfactor,tenor,term,moneyness);
                            
                % add convexity adjustment to forward rate
                if ( instrument.convex_adj == true )
                    adj_rate = calcConvexityAdjustment(valuation_date, ...
                            instrument, forward_rate_curve,sigma,t1,t2);
                else
                    adj_rate = forward_rate_curve;
                end
                % calculate forward rate according to CAP/FLOOR model
                forward_rate = getCapFloorRate(instrument.CapFlag, ...
                        adj_rate, X, tf_fsd, sigma, instrument.model);
                % adjust forward rate to term of caplet / floorlet
                forward_rate = forward_rate .* tf;
            else % all other floating swap legs and floater
                forward_rate = (spread + forward_rate_curve) .* tf;
            end
        elseif ( t1 < 0 && t2 > 0 )     % if last cf date is in the past, while
                                        % next is in future, use last reset rate
            if (strcmpi(type,'CAP') || strcmpi(type,'FLOOR'))
                if instrument.CapFlag == true
                    forward_rate = max(last_reset_rate - instrument.strike,0) .* tf;
                else
                    forward_rate = max(instrument.strike - last_reset_rate,0) .* tf;
                end
            else
                forward_rate = (spread + last_reset_rate) .* tf;
            end
        else    % if both cf dates t1 and t2 lie in the past omit cash flow
            forward_rate = 0.0;
        end
        cf_values(:,ii) = forward_rate;
    end
    ret_values = cf_values .* notional;
    cf_interest = ret_values;
    % Add notional payments
    if ( notional_at_start == true)    % At notional payment at start
        ret_values(:,1) = ret_values(:,1) - notional;  
        cf_principal(:,1) = - notional;
    end
    if ( notional_at_end == true) % Add notional payment at end to cf vector:
        ret_values(:,end) = ret_values(:,end) + notional;
        cf_principal(:,end) = notional;
    end
    
% Type ZCB: Zero Coupon Bond has notional cash flow at maturity date
elseif ( strcmp(type,'ZCB') == 1 )   
    ret_values = notional;
    cf_principal = notional;
    cf_interest = 0;
    
% Type FAB: Calculate CF Values for all CF Periods for fixed amortizing bonds 
%           (annuity loans and amortizable loans)

elseif ( strcmp(type,'FAB') == 1 )
    % TODO: if given amount outstanding shall be used for calculation cash flows,
    % do the following: set issue date to valuation date, set notional to 
    % amount outstanding, remove all cf_dates < 0, make new attribute specifying
    % is outstanding amount shall be used
    % fixed annuity: fixed total payments 
    if ( fixed_annuity_flag == 1)    
        number_payments = length(cf_dates) -1;
        m = comp_freq;
        total_term = number_payments / m ; % total term of annuity in years      
        % Discrete compounding only with act/365 day count convention
        % TODO: implement simple and continuous compounding for annuity 
        %       calculation
        if ( in_arrears_flag == 1)  % in arrears payments (at end of period)    
            rate = (notional * (( 1 + coupon_rate )^total_term * coupon_rate ) ... 
                                / (( 1 + coupon_rate  )^total_term - 1) ) ...
                                / (m + coupon_rate / 2 * ( m + 1 ));            
        else                        % in advance payments
            rate = (notional * (( 1 + coupon_rate )^total_term * coupon_rate ) ...
                                / (( 1 + coupon_rate )^total_term - 1) ) ...
                                / (m + coupon_rate / 2 * ( m - 1 ));   
        end
        ret_values = ones(1,number_payments) .* rate;
        
        % calculate principal and interest cf
        cf_datesnum = datenum(cf_dates);
        d1 = cf_datesnum(1:length(cf_datesnum)-1);
        d2 = cf_datesnum(2:length(cf_datesnum));
        cf_interest = zeros(1,number_payments);
        amount_outstanding_vec = zeros(1,number_payments);
        amount_outstanding_vec(1) = notional;
        % cashflows of first date
        cf_interest(1) = notional.* ((1 ./ discount_factor (d1(1), d2(1), ...
                    coupon_rate, compounding_type, dcc, compounding_freq)) - 1); 
        % cashflows of remaining dates
        for ii = 2 : 1 : number_payments
            amount_outstanding_vec(ii) = amount_outstanding_vec(ii - 1) ... 
                                        - ( rate -  cf_interest(ii-1) );
            cf_interest(ii) = amount_outstanding_vec(ii) .* ((1 ./ ...
                            discount_factor (d1(ii), d2(ii), coupon_rate, ...
                                 compounding_type, dcc, compounding_freq)) - 1);          
        end
        cf_principal = rate - cf_interest;
    % fixed amortization: only amortization is fixed, coupon payments are 
    %                       variable
    else
        % given principal payments, used at each cash flow date for amortization
        if ( use_principal_pmt_flag == 1)
            number_payments = length(cf_dates) -1;
            m = comp_freq;
            princ_pmt = instrument.principal_payment;
            % calculate principal and interest cf
            cf_datesnum = datenum(cf_dates);
            d1 = cf_datesnum(1:length(cf_datesnum)-1);
            d2 = cf_datesnum(2:length(cf_datesnum));
            cf_interest = zeros(1,number_payments);
            amount_outstanding_vec = zeros(1,number_payments);
            amount_outstanding_vec(1) = notional;
            % cashflows of first date
            cf_interest(1) = notional.* ((1 ./ discount_factor (d1(1), d2(1), ...
                        coupon_rate, compounding_type, dcc, compounding_freq)) - 1); 
            % cashflows of remaining dates
            for ii = 2 : 1 : number_payments
                amount_outstanding_vec(ii) = amount_outstanding_vec(ii - 1) ... 
                                            - princ_pmt;
                cf_interest(ii) = amount_outstanding_vec(ii) .* ((1 ./ ...
                                discount_factor (d1(ii), d2(ii), coupon_rate, ...
                                     compounding_type, dcc, compounding_freq)) - 1);          
            end
            cf_principal = princ_pmt .* ones(1,number_payments);
            % add outstanding amount at maturity to principal cashflows
            cf_principal(end) = amount_outstanding_vec(end);
            ret_values = cf_principal + cf_interest;
        % fixed amortization rate, total amortization of bond until maturity
        else 
            number_payments = length(cf_dates) -1;
            m = comp_freq;
            total_term = number_payments / m;   % total term of annuity in years
            amortization_rate = notional / number_payments;  
            cf_datesnum = datenum(cf_dates);
            d1 = cf_datesnum(1:length(cf_datesnum)-1);
            d2 = cf_datesnum(2:length(cf_datesnum));
            cf_values = zeros(1,number_payments);
            amount_outstanding = notional;
            amount_outstanding_vec = zeros(number_payments,1);
            for ii = 1: 1 : number_payments
                cf_values(ii) = ((1 ./ discount_factor (d1(ii), d2(ii), ...
                                      coupon_rate, compounding_type, dcc, ...
                                      compounding_freq)) - 1) .* amount_outstanding;
                amount_outstanding = amount_outstanding - amortization_rate;
                amount_outstanding_vec(ii) = amount_outstanding;
            end
            ret_values = cf_values + amortization_rate;
            cf_principal = amortization_rate;
            cf_interest = cf_values;
        %amount_outstanding_vec
        end
    end  
    % prepayment: calculate modified cash flows while including prepayment
    if ( instrument.prepayment_flag == 1)
        
        % Calculation rule:
        % Extract PSA factor either from provided prepayment surface (depending
        % on coupon_rate of FAB instrument and absolute ir shock or kept at 1.
        % The absolute ir shock is extracted from a factor weighing absolute
        % difference of the riskfactor curve base values to value_type values.
        % Then this PSA factor is kept constant for all FAB cash flows.
        % The PSA prepayment rate is extracted either from a constant prepayment
        % rate or from the ref_curve (PSA prepayment rate curve) depending
        % on the cash flow term.
        % Prepayment_rate(i) = psa_factor(const) * PSA_prepayment(i)
        % This prepayment rate is then used to iteratively calculated
        % prepaid principal values and interest rate.
        % 
        % Implementation: use either constant prepayment rate or use prepayment 
        %                   curve for calculation of scaling factor
        pp_type = instrument.prepayment_type; % either full or default
        use_outstanding_balance = instrument.use_outstanding_balance;
        % case 1: prepayment curve:   
        if ( strcmpi(instrument.prepayment_source,'curve'))
            pp_curve_interp = method_interpolation;
            pp_curve_nodes = tmp_nodes;
            pp_curve_values = tmp_rates;
        % case 2: constant prepayment rate: set up pseudo constant curve
        elseif ( strcmpi(instrument.prepayment_source,'rate'))
            pp_curve_interp = 'linear';
            pp_curve_nodes = [0];
            pp_curve_values = instrument.prepayment_rate;
            comp_type_curve = 'cont';
            basis_curve = 3;
            comp_freq_curve = 'annual';
        end
        
        % generate PSA factor dummy surface if not provided
        if (nargin < 5 ||  ~isobject(surface)) 
            pp = Surface();
            pp = pp.set('axis_x',[0.01],'axis_x_name','coupon_rate','axis_y',[0.0], ...
                'axis_y_name','ir_shock','values_base',[1],'type','PREPAYMENT');
        else % take provided PSA factor surface
            pp = surface;
        end
        
        % preallocate memory
        cf_principal_pp = zeros(rows(pp_curve_values),number_payments);
        cf_interest_pp = zeros(rows(pp_curve_values),number_payments);
        
        % calculate absolute IR shock from provided riskfactor curve
        if (nargin < 6 ||  ~isobject(riskfactor)) 
            abs_ir_shock = 0.0;
        else    % calculate absolute IR shock of scenario minus base scenario
            abs_ir_shock_rates =  riskfactor.getValue(value_type) ...
                                - riskfactor.getValue('base');
            % interpolate shock at factor term structure
            abs_ir_shock = 0.0;
            for ff = 1 : 1 : length(instrument.psa_factor_term)
                abs_ir_shock = abs_ir_shock + interpolate_curve(riskfactor.nodes, ...
                                                        abs_ir_shock_rates,ff);    
            end
            abs_ir_shock = abs_ir_shock ./ length(instrument.psa_factor_term);
        end
        % extract PSA factor from prepayment procedure (independent of PSA curve)
        prepayment_factor = pp.getValue(coupon_rate,abs_ir_shock);
                
        % case 1: full prepayment with rate from prepayment curve or 
        %           constant rate
        if ( strcmpi(pp_type,'full'))
            Q_scaling = ones(rows(pp_curve_values),1);
            % if outstanding balance should not be used, the prepayment from
            % all cash flows since issue date are recalculated
            if ( use_outstanding_balance == 0 )
                for ii = 1 : 1 : number_payments 
                     % get prepayment rate at days to cashflow
                    tmp_timestep = d2(ii) - d2(1); 
                    % extract PSA factor from prepayment procedure               
                    prepayment_rate = interpolate_curve(pp_curve_nodes, ...
                                    pp_curve_values,tmp_timestep,pp_curve_interp);
                    prepayment_rate = prepayment_rate .* prepayment_factor;
                    % convert annualized prepayment rate
                    lambda = ((1 ./ discount_factor (d1(ii), d2(ii), ...
                    prepayment_rate, comp_type_curve, basis_curve, comp_freq_curve)) - 1);  

                    %       (cf_principal_pp will be matrix (:,ii))
                    cf_principal_pp(:,ii) = Q_scaling .* ( cf_principal(ii) ...
                                        + lambda .* ( amount_outstanding_vec(ii) ...
                                        -  cf_principal(ii ) ));
                    cf_interest_pp(:,ii) = cf_interest(ii) .* Q_scaling;
                    % calculate new scaling Factor
                    Q_scaling = Q_scaling .* (1 - lambda);
                end
            % use_outstanding_balance = true: recalculate cash flow values from
            % valuation date (notional = outstanding_balance) until maturity
            % with current prepayment rates and psa factors
            else
                out_balance = instrument.outstanding_balance;
                % use only payment dates > valuation date  
                cf_datesnum = datenum(cf_dates);
                original_payments = length(cf_dates);
                number_payments = length(cf_datesnum);
                d1 = cf_datesnum(1:length(cf_datesnum)-1);
                d2 = cf_datesnum(2:length(cf_datesnum));
                % preallocate memory
                amount_outstanding_vec = zeros(rows(prepayment_factor),number_payments) ...
                                                                .+ out_balance;              
                cf_interest_pp = zeros(rows(prepayment_factor),number_payments);
                cf_principal_pp = zeros(rows(prepayment_factor),number_payments); 
                cf_annuity = zeros(rows(prepayment_factor),number_payments);                
                issue_date = datenum(instrument.issue_date);
                % calculate all principal and interest cash flows including
                % prepayment cashflows. use future cash flows only
                for ii = 1 : 1 : number_payments
                    if ( cf_datesnum(ii) > valuation_date)
                        eff_notional = amount_outstanding_vec(:,ii-1);
                         % get prepayment rate at days to cashflow
                        tmp_timestep = d2(ii-1) - issue_date;
                        % extract PSA factor from prepayment procedure               
                        prepayment_rate = interpolate_curve(pp_curve_nodes, ...
                                        pp_curve_values,tmp_timestep,pp_curve_interp);
                        prepayment_rate = prepayment_rate .* prepayment_factor;
                        % convert annualized prepayment rate
                        lambda = ((1 ./ discount_factor (d1(ii-1), d2(ii-1), ...
                                            prepayment_rate, comp_type_curve, ...
                                            basis_curve, comp_freq_curve)) - 1);
                        % calculate interest cashflow
                        [tf dip dib] = timefactor (d1(ii-1), d2(ii-1), dcc);
                        eff_rate = coupon_rate .* tf; 
                        cf_interest_pp(:,ii) = eff_rate .* eff_notional;
                        
                        % annuity principal
                        rem_cf = 1 + number_payments - ii;  %remaining cash flows
                        tmp_interest = cf_interest_pp(:,ii);
                        tmp_divisor = (1 - (1 + eff_rate) .^ (-rem_cf));
                        cf_annuity(:,ii) = tmp_interest ./ tmp_divisor - tmp_interest;
                        
                        %cf_scaled_annuity = (1 - lambda) .* cf_annuity(:,ii);
                        cf_prepayment = eff_notional .* lambda;
                        cf_principal_pp(:,ii) = (1 - lambda) .* cf_annuity(:,ii) + cf_prepayment;
                        %tmp_annuity = cf_annuity(:,ii)
                        %tmp_scaled_annuity = (1 - lambda) .* tmp_annuity
                        % calculate new amount outstanding (remaining amount >0)
                        amount_outstanding_vec(:,ii) = max(0,eff_notional-cf_principal_pp(:,ii));
                    end
                end
            end
        % case 2: TODO implementation
        elseif ( strcmpi(pp_type,'default'))
            cf_interest_pp = cf_interest;
            cf_principal_pp = cf_principal;
        end 
        ret_values_pp = cf_interest_pp + cf_principal_pp;
        % overwrite original values with values including prepayments
        ret_values = ret_values_pp;
        cf_principal = cf_principal_pp;
        cf_interest = cf_interest_pp;
        
    end % end prepayment procedure
end
%-------------------------------------------------------------------------------

ret_dates_tmp = datenum(cf_business_dates);
ret_dates = ret_dates_tmp(2:rows(cf_business_dates));
if enable_business_day_rule == 1
    pay_dates = cf_business_dates;
else
    pay_dates = cf_dates;
end
pay_dates(1,:)=[];
ret_dates = datenum(pay_dates)' - valuation_date;
ret_dates_tmp = ret_dates;              % store all cf dates for later use
ret_dates = ret_dates(ret_dates>0);

ret_values = ret_values(:,(end-length(ret_dates)+1):end);
ret_interest_values = cf_interest(:,(end-length(ret_dates)+1):end);
ret_principal_values = cf_principal(:,(end-length(ret_dates)+1):end);
%-------------------------------------------------------------------------------
% #################   Calculation of accrued interests   #######################   
%
% calculate time in days from last coupon date
ret_date_last_coupon = ret_dates_tmp(ret_dates_tmp<0);

% distinguish three different cases:
% A) issue_date.......first_cf_date....valuation_date...2nd_cf_date.....mat_date
% B) valuation_date...issue_date......frist_cf_date.....2nd_cf_date.....mat_date
% C) issue_date.......valuation_date..frist_cf_date.....2nd_cf_date.....mat_date

% adjustment to accrued interest required if calculated
% from next cashflow (background: next cashflow is adjusted for
% for actual days in period (in e.g. act/365 dcc), so the
% CF has to be adjusted back by 355/366 in leap year to prevent
% double counting of one day
% therefore a generic approach was chosen where the time factor is always 
% adjusted by actual days in year / days in leap year

if length(ret_date_last_coupon) > 0                 % CASE A
    last_coupon_date = ret_date_last_coupon(end);
    ret_date_last_coupon = -ret_date_last_coupon(end);  
    [tf dip dib] = timefactor (valuation_date - ret_date_last_coupon, ...
                            valuation_date, dcc);
    % correct next coupon payment if leap year
    % adjustment from 1 to 365 days in base for act/act
    if dib == 1
        dib = 365;
    end    
    days_from_last_coupon = ret_date_last_coupon;
    days_to_next_coupon = ret_dates(1);  
    adj_factor = dib / (days_from_last_coupon + days_to_next_coupon);
    if ~( term == 365)
    adj_factor = adj_factor .* term / 12;
    end
    tf = tf * adj_factor;
else
    % last coupon date is first coupon date for Cases B and C:
    last_coupon_date = ret_dates(1);
    % if valuation date before issue date -> tf = 0
    if ( valuation_date <= datenum(issue_date) )    % CASE B
        tf = 0;
        
    % valuation date after issue date, but before first cf payment date
    else                                            % CASE C
        [tf dip dib] = timefactor (issue_date, valuation_date, dcc);
        days_from_last_coupon = valuation_date - datenum(issue_date);
        days_to_next_coupon = ret_dates(1) ; 
        adj_factor = dib / (days_from_last_coupon + days_to_next_coupon);
        if ~( term == 365)
        adj_factor = adj_factor * term / 12;
        end
        tf = tf .* adj_factor;
    end
end
% value of next coupon -> accrued interest is pro-rata share of next coupon
ret_value_next_coupon = ret_interest_values(:,1);

% scale tf according to term:
if ~( term == 365)
    tf = tf * 12 / term;
end
accrued_interest = ret_value_next_coupon .* tf;

%-------------------------------------------------------------------------------

end



%-------------------------------------------------------------------------------
%                           Helper Functions
%-------------------------------------------------------------------------------
function new_cf_day = check_day(cf_year,cf_month,cf_day)
 % error checking for valid days 29,30 or 31 at end of month
        if ( cf_day <= 28 )
            new_cf_day = cf_day;
        elseif ( cf_day == 29 || cf_day == 30 )
            if ( cf_month == 2 )
                if ( yeardays(cf_year) == 366 )
                    new_cf_day = 29;
                else
                    new_cf_day = 28;
                end
            else
                new_cf_day = cf_day;
            end
        elseif ( cf_day == 31 ) 
            new_cf_day = eomday (cf_year, cf_month);
        end
        
end

%!test
%! bond_struct=struct();
%! bond_struct.sub_type                 = 'FRB';
%! bond_struct.issue_date               = '21-Sep-2010';
%! bond_struct.maturity_date            = '17-Sep-2022';
%! bond_struct.compounding_type         = 'simple';
%! bond_struct.compounding_freq         = 1  ;
%! bond_struct.term                     = 12   ;
%! bond_struct.day_count_convention     = 'act/365';
%! bond_struct.basis                    = 3;
%! bond_struct.notional                 = 100 ;
%! bond_struct.coupon_rate              = 0.035; 
%! bond_struct.coupon_generation_method = 'backward' ;
%! bond_struct.business_day_rule        = 0 ;
%! bond_struct.business_day_direction   = 1  ;
%! bond_struct.enable_business_day_rule = 0;
%! bond_struct.spread                   = 0.00 ;
%! bond_struct.long_first_period        = false;
%! bond_struct.long_last_period         = false;
%! bond_struct.last_reset_rate          = 0.0000000;
%! bond_struct.fixed_annuity            = 1;
%! bond_struct.in_arrears               = 0;
%! bond_struct.notional_at_start        = false;
%! bond_struct.notional_at_end          = true;
%! bond_struct.prepayment_flag          = false;
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('31-Mar-2016','base',bond_struct);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_dates,[170,535,900,1265,1631,1996,2361]);

%!test
%! bond_struct=struct();
%! bond_struct.sub_type                 = 'FRB';
%! bond_struct.issue_date               = '21-Sep-2010';
%! bond_struct.maturity_date            = '17-Sep-2022';
%! bond_struct.compounding_type         = 'simple';
%! bond_struct.compounding_freq         = 1  ;
%! bond_struct.term                     = 12   ;
%! bond_struct.day_count_convention     = 'act/365';
%! bond_struct.basis                    = 3;
%! bond_struct.notional                 = 100 ;
%! bond_struct.coupon_rate              = 0.035; 
%! bond_struct.coupon_generation_method = 'backward' ;
%! bond_struct.business_day_rule        = 0 ;
%! bond_struct.business_day_direction   = 1  ;
%! bond_struct.enable_business_day_rule = 0;
%! bond_struct.spread                   = 0.00 ;
%! bond_struct.long_first_period        = false;
%! bond_struct.long_last_period         = false;
%! bond_struct.last_reset_rate          = 0.0000000;
%! bond_struct.fixed_annuity            = 1;
%! bond_struct.in_arrears               = 0;
%! bond_struct.notional_at_start        = false;
%! bond_struct.notional_at_end          = true;
%! bond_struct.prepayment_flag          = false;
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('31-Mar-2016','base',bond_struct);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_values,[3.5096,3.5000,3.5000,3.5000,3.5096,3.5000,103.5000],0.0001);

%!test
%! bond_struct=struct();
%! bond_struct.sub_type                 = 'FAB';
%! bond_struct.issue_date               = '01-Nov-2011';
%! bond_struct.maturity_date            = '01-Nov-2021';
%! bond_struct.compounding_type         = 'simple';
%! bond_struct.compounding_freq         = 1  ;
%! bond_struct.term                     = 12   ;
%! bond_struct.day_count_convention     = 'act/365';
%! bond_struct.basis                    = 3;
%! bond_struct.notional                 = 100 ;
%! bond_struct.coupon_rate              = 0.0333; 
%! bond_struct.coupon_generation_method = 'backward' ;
%! bond_struct.business_day_rule        = 0 ;
%! bond_struct.business_day_direction   = 1  ;
%! bond_struct.enable_business_day_rule = 0;
%! bond_struct.spread                   = 0.00 ;
%! bond_struct.long_first_period        = false;
%! bond_struct.long_last_period         = false;
%! bond_struct.last_reset_rate          = 0.0000000;
%! bond_struct.fixed_annuity            = 1;
%! bond_struct.in_arrears               = 0;
%! bond_struct.notional_at_start        = false;
%! bond_struct.notional_at_end          = true;
%! bond_struct.prepayment_flag          = false;
%! bond_struct.use_principal_pmt        = 0;
%! bond_struct.use_outstanding_balance  = 0;
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('01-Nov-2011','base',bond_struct);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_values,11.92133107 .* ones(1,10),0.00001);

%!test
%! bond_struct=struct();
%! bond_struct.sub_type                 = 'FAB';
%! bond_struct.issue_date               = '01-Nov-2011';
%! bond_struct.maturity_date            = '01-Nov-2021';
%! bond_struct.compounding_type         = 'simple';
%! bond_struct.compounding_freq         = 1  ;
%! bond_struct.term                     = 12   ;
%! bond_struct.day_count_convention     = 'act/365';
%! bond_struct.basis                    = 3;
%! bond_struct.notional                 = 100 ;
%! bond_struct.coupon_rate              = 0.0333; 
%! bond_struct.coupon_generation_method = 'backward' ;
%! bond_struct.business_day_rule        = 0 ;
%! bond_struct.business_day_direction   = 1  ;
%! bond_struct.enable_business_day_rule = 0;
%! bond_struct.spread                   = 0.00 ;
%! bond_struct.long_first_period        = false;
%! bond_struct.long_last_period         = false;
%! bond_struct.last_reset_rate          = 0.0000000;
%! bond_struct.fixed_annuity            = 1;
%! bond_struct.in_arrears               = 0;
%! bond_struct.notional_at_start        = false;
%! bond_struct.notional_at_end          = true;
%! bond_struct.prepayment_type          = 'full';  % ['full','default']
%! bond_struct.prepayment_source        = 'curve'; % ['curve','rate']
%! bond_struct.prepayment_flag          = true;
%! bond_struct.prepayment_rate          = 0.00; 
%! bond_struct.use_principal_pmt        = 0;
%! bond_struct.use_outstanding_balance  = 0;
%! c = Curve();
%! c = c.set('id','PSA_CURVE','nodes',[0,900],'rates_stress',[0.0,0.06;0.0,0.08;0.01,0.10],'method_interpolation','linear','compounding_type','simple');
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('01-Nov-2011','stress',bond_struct,c);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_values(:,end),[7.63168805976622;6.53801392731666;5.48158314020277 ],0.0000001);     

%!test 
%! bond_struct=struct();
%! bond_struct.sub_type                 = 'SWAP_FLOATING';
%! bond_struct.issue_date               = '31-Mar-2018';
%! bond_struct.maturity_date            = '28-Mar-2028';
%! bond_struct.compounding_type         = 'disc';
%! bond_struct.compounding_freq         = 1;
%! bond_struct.term                     = 365;
%! bond_struct.day_count_convention     = 'act/365';
%! bond_struct.basis                    = 3;
%! bond_struct.notional                 = 100 ;
%! bond_struct.coupon_rate              = 0.00; 
%! bond_struct.coupon_generation_method = 'forward' ;
%! bond_struct.business_day_rule        = 0 ;
%! bond_struct.business_day_direction   = 1  ;
%! bond_struct.enable_business_day_rule = 0;
%! bond_struct.spread                   = 0.00 ;
%! bond_struct.long_first_period        = false;
%! bond_struct.long_last_period         = false;
%! bond_struct.last_reset_rate          = 0.0000000;
%! bond_struct.fixed_annuity            = 1;
%! bond_struct.in_arrears               = 0;
%! bond_struct.notional_at_start        = false;
%! bond_struct.notional_at_end          = false;
%! bond_struct.prepayment_type          = 'full';  % ['full','default']
%! bond_struct.prepayment_source        = 'curve'; % ['curve','rate']
%! bond_struct.prepayment_flag          = true;
%! bond_struct.prepayment_rate          = 0.00; 
%! discount_nodes = [730,1095,1460,1825,2190,2555,2920,3285,3650,4015,4380];
%! discount_rates = [0.0001001034,0.0001000689,0.0001000684,0.0001000962,0.0003066350,0.0013812064,0.002484882,0.0035760168,0.0045624391,0.0054502705,0.0062599362];
%! c = Curve();
%! c = c.set('id','IR_EUR','nodes',discount_nodes,'rates_base',discount_rates,'method_interpolation','linear');
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('31-Mar-2016','base',bond_struct,c);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_values(end),1.5281850227882421,0.000000001);
%! assert(ret_values(1),0.0100004900156492,0.000000001);

%!test 
%! cap_struct=struct();
%! cap_struct.sub_type                 = 'CAP';
%! cap_struct.issue_date               = '31-Mar-2017';
%! cap_struct.maturity_date            = '30-Jun-2017';
%! cap_struct.compounding_type         = 'cont';
%! cap_struct.compounding_freq         = 1;
%! cap_struct.term                     = 3;
%! cap_struct.day_count_convention     = 'act/365';
%! cap_struct.basis                    = 3;
%! cap_struct.notional                 = 10000 ;
%! cap_struct.coupon_rate              = 0.00; 
%! cap_struct.coupon_generation_method = 'forward' ;
%! cap_struct.business_day_rule        = 0 ;
%! cap_struct.business_day_direction   = 1  ;
%! cap_struct.enable_business_day_rule = 0;
%! cap_struct.spread                   = 0.00 ;
%! cap_struct.long_first_period        = false;
%! cap_struct.long_last_period         = false;
%! cap_struct.last_reset_rate          = 0.0000000;
%! cap_struct.fixed_annuity            = 1;
%! cap_struct.in_arrears               = 0;
%! cap_struct.notional_at_start        = false;
%! cap_struct.notional_at_end          = false;
%! cap_struct.strike                   = 0.08;
%! cap_struct.CapFlag                  = true;
%! cap_struct.model                    = 'Black';
%! cap_struct.convex_adj               = true;
%! cap_struct.vola_spread              = 0.0;
%! ref_nodes = [365,730];
%! ref_rates = [0.07,0.07];
%! c = Curve();
%! c = c.set('id','IR_EUR','nodes',ref_nodes,'rates_base',ref_rates,'method_interpolation','linear');
%! v = Surface();
%! v = v.set('axis_x',365,'axis_x_name','TENOR','axis_y',90,'axis_y_name','TERM','axis_z',1.0,'axis_z_name','MONEYNESS');
%! v = v.set('values_base',0.2);
%! v = v.set('type','IR');
%! r = Riskfactor();
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('31-Mar-2016','base',cap_struct,c,v,r);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_dates,456,0.000000001);
%! assert(ret_values,5.63130599411650,0.000000001);

%!test 
%! cap_struct=struct();
%! cap_struct.sub_type                 = 'FLOOR';
%! cap_struct.issue_date               = '30-Dec-2018';
%! cap_struct.maturity_date            = '29-Dec-2020';
%! cap_struct.compounding_type         = 'simple';
%! cap_struct.compounding_freq         = 1;
%! cap_struct.term                     = 365;
%! cap_struct.day_count_convention     = 'act/365';
%! cap_struct.basis                    = 3;
%! cap_struct.notional                 = 10000;
%! cap_struct.coupon_rate              = 0.00; 
%! cap_struct.coupon_generation_method = 'forward' ;
%! cap_struct.business_day_rule        = 0 ;
%! cap_struct.business_day_direction   = 1  ;
%! cap_struct.enable_business_day_rule = 0;
%! cap_struct.spread                   = 0.00 ;
%! cap_struct.long_first_period        = false;
%! cap_struct.long_last_period         = false;
%! cap_struct.last_reset_rate          = 0.0000000;
%! cap_struct.notional_at_start        = false;
%! cap_struct.notional_at_end          = false;
%! cap_struct.strike                   = 0.005;
%! cap_struct.in_arrears               = 0;
%! cap_struct.CapFlag                  = true;
%! cap_struct.model                    = 'Black';
%! cap_struct.convex_adj               = true;
%! cap_struct.vola_spread              = 0.0;
%! ref_nodes = [30,1095,1460];
%! ref_rates = [0.01,0.01,0.01];
%! sigma                               = 0.8000;
%! c = Curve();
%! c = c.set('id','IR_EUR','nodes',ref_nodes,'rates_base',ref_rates,'method_interpolation','linear');
%! v = Surface();
%! v = v.set('axis_x',365,'axis_x_name','TENOR','axis_y',90,'axis_y_name','TERM','axis_z',1.0,'axis_z_name','MONEYNESS');
%! v = v.set('values_base',sigma);
%! v = v.set('type','IR');
%! r = Riskfactor();
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('31-Dec-2015','base',cap_struct,c,v,r);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_dates,[1460,1825]);
%! assert(ret_values,[69.3193486314239,74.0148444015558],0.000000001);

%!test 
%! cap_struct=struct();
%! cap_struct.sub_type                 = 'CAP';
%! cap_struct.issue_date               = '30-Dec-2018';
%! cap_struct.maturity_date            = '29-Dec-2020';
%! cap_struct.compounding_type         = 'simple';
%! cap_struct.compounding_freq         = 1;
%! cap_struct.term                     = 365;
%! cap_struct.day_count_convention     = 'act/365';
%! cap_struct.basis                    = 3;
%! cap_struct.notional                 = 10000;
%! cap_struct.coupon_rate              = 0.00; 
%! cap_struct.coupon_generation_method = 'forward' ;
%! cap_struct.business_day_rule        = 0 ;
%! cap_struct.business_day_direction   = 1  ;
%! cap_struct.enable_business_day_rule = 0;
%! cap_struct.spread                   = 0.00 ;
%! cap_struct.long_first_period        = false;
%! cap_struct.long_last_period         = false;
%! cap_struct.last_reset_rate          = 0.0000000;
%! cap_struct.notional_at_start        = false;
%! cap_struct.notional_at_end          = false;
%! cap_struct.strike                   = 0.005;
%! cap_struct.in_arrears               = 0;
%! cap_struct.CapFlag                  = true;
%! cap_struct.model                    = 'Normal';
%! cap_struct.convex_adj               = false;
%! cap_struct.vola_spread              = 0.0;
%! ref_nodes = [30,1095,1460];
%! ref_rates = [0.01,0.01,0.01];
%! sigma                               = 0.00555;
%! c = Curve();
%! c = c.set('id','IR_EUR','nodes',ref_nodes,'rates_base',ref_rates,'method_interpolation','linear');
%! v = Surface();
%! v = v.set('axis_x',365,'axis_x_name','TENOR','axis_y',90,'axis_y_name','TERM','axis_z',1.0,'axis_z_name','MONEYNESS');
%! v = v.set('values_base',sigma);
%! v = v.set('type','IR');
%! r = Riskfactor();
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('31-Dec-2015','base',cap_struct,c,v,r);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_dates,[1460,1825]);
%! assert(ret_values,[68.7744654466300,74.03917364111012],0.000000001);
   
%!test 
%! cap_struct=struct();
%! cap_struct.sub_type                 = 'FLOOR';
%! cap_struct.issue_date               = '30-Dec-2018';
%! cap_struct.maturity_date            = '29-Dec-2020';
%! cap_struct.compounding_type         = 'simple';
%! cap_struct.compounding_freq         = 1;
%! cap_struct.term                     = 365;
%! cap_struct.day_count_convention     = 'act/365';
%! cap_struct.basis                    = 3;
%! cap_struct.notional                 = 10000;
%! cap_struct.coupon_rate              = 0.00; 
%! cap_struct.coupon_generation_method = 'forward' ;
%! cap_struct.business_day_rule        = 0 ;
%! cap_struct.business_day_direction   = 1  ;
%! cap_struct.enable_business_day_rule = 0;
%! cap_struct.spread                   = 0.00 ;
%! cap_struct.long_first_period        = false;
%! cap_struct.long_last_period         = false;
%! cap_struct.last_reset_rate          = 0.0000000;
%! cap_struct.notional_at_start        = false;
%! cap_struct.notional_at_end          = false;
%! cap_struct.strike                   = 0.005;
%! cap_struct.in_arrears               = 0;
%! cap_struct.CapFlag                  = false;
%! cap_struct.model                    = 'Normal';
%! cap_struct.convex_adj               = false;
%! cap_struct.vola_spread              = 0.0;
%! ref_nodes = [30,1095,1460];
%! ref_rates = [0.01,0.01,0.01];
%! sigma                               = 0.00555;
%! c = Curve();
%! c = c.set('id','IR_EUR','nodes',ref_nodes,'rates_base',ref_rates,'method_interpolation','linear');
%! v = Surface();
%! v = v.set('axis_x',365,'axis_x_name','TENOR','axis_y',90,'axis_y_name','TERM','axis_z',1.0,'axis_z_name','MONEYNESS');
%! v = v.set('values_base',sigma);
%! v = v.set('type','IR');
%! r = Riskfactor();
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('31-Dec-2015','base',cap_struct,c,v,r);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_dates,[1460,1825]);
%! assert(ret_values,[18.2727946049505,23.5375027994284],0.000000001);
   
%!test 
%! bond_struct=struct();
%! bond_struct.sub_type                 = 'ZCB';
%! bond_struct.issue_date               = '31-Mar-2016';
%! bond_struct.maturity_date            = '30-Mar-2021';
%! bond_struct.compounding_type         = 'disc';
%! bond_struct.compounding_freq         = 1;
%! bond_struct.term                     = 365;
%! bond_struct.day_count_convention     = 'act/365';
%! bond_struct.basis                    = 3;
%! bond_struct.notional                 = 1 ;
%! bond_struct.coupon_rate              = 0.00; 
%! bond_struct.coupon_generation_method = 'forward' ;
%! bond_struct.business_day_rule        = 0 ;
%! bond_struct.business_day_direction   = 1  ;
%! bond_struct.enable_business_day_rule = 0;
%! bond_struct.spread                   = 0.00 ;
%! bond_struct.long_first_period        = false;
%! bond_struct.long_last_period         = false;
%! bond_struct.last_reset_rate          = 0.0000000;
%! bond_struct.fixed_annuity            = 1;
%! bond_struct.in_arrears               = 0;
%! bond_struct.notional_at_start        = false;
%! bond_struct.notional_at_end          = false;
%! comp_type_curve                      = 'cont';
%! basis_curve                          = 'act/act';
%! comp_freq_curve                      = 'annual';
%! discount_nodes = [1825];
%! discount_rates = [0.0001000962];
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('31-Mar-2016','base',bond_struct);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_dates,1825);
%! assert(ret_values,1);

%!test
%! bond_struct=struct();
%! bond_struct.sub_type                 = 'FRB';
%! bond_struct.issue_date               = '22-Nov-2011';
%! bond_struct.maturity_date            = '09-Nov-2026';
%! bond_struct.compounding_type         = 'simple';
%! bond_struct.compounding_freq         = 1  ;
%! bond_struct.term                     = 12   ;
%! bond_struct.day_count_convention     = 'act/365';
%! bond_struct.basis                    = 3;
%! bond_struct.notional                 = 100 ;
%! bond_struct.coupon_rate              = 0.015; 
%! bond_struct.coupon_generation_method = 'backward' ;
%! bond_struct.business_day_rule        = 0 ;
%! bond_struct.business_day_direction   = 1  ;
%! bond_struct.enable_business_day_rule = 0;
%! bond_struct.spread                   = 0.00 ;
%! bond_struct.long_first_period        = false;
%! bond_struct.long_last_period         = false;
%! bond_struct.last_reset_rate          = 0.0000000;
%! bond_struct.fixed_annuity            = 1;
%! bond_struct.in_arrears               = 0;
%! bond_struct.notional_at_start        = false;
%! bond_struct.notional_at_end          = true;
%! bond_struct.prepayment_flag          = false;
%! [ret_dates ret_values ret_int ret_princ accrued_interest] = rollout_structured_cashflows('31-Dec-2015','base',bond_struct);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_dates,[314,679,1044,1409,1775,2140,2505,2870,3236,3601,3966],0.000000001);
%! assert(ret_values,[1.504109589,1.5,1.5,1.5,1.504109589,1.5,1.5,1.5,1.504109589,1.5,101.5],0.000000001);
%! assert(accrued_interest,0.213698630136987,0.0000001);

%!test
%! bond_struct=struct();
%! bond_struct.sub_type                 = 'FRB';
%! bond_struct.issue_date               = '22-Nov-2011';
%! bond_struct.maturity_date            = '30-Sep-2021';
%! bond_struct.compounding_type         = 'simple';
%! bond_struct.compounding_freq         = 1;
%! bond_struct.term                     = 6;
%! bond_struct.day_count_convention     = 'act/365';
%! bond_struct.basis                    = 3;
%! bond_struct.notional                 = 100 ;
%! bond_struct.coupon_rate              = 0.02125; 
%! bond_struct.coupon_generation_method = 'backward' ;
%! bond_struct.business_day_rule        = 0 ;
%! bond_struct.business_day_direction   = 1  ;
%! bond_struct.enable_business_day_rule = 0;
%! bond_struct.spread                   = 0.00 ;
%! bond_struct.long_first_period        = false;
%! bond_struct.long_last_period         = false;
%! bond_struct.last_reset_rate          = 0.0000000;
%! bond_struct.fixed_annuity            = 1;
%! bond_struct.in_arrears               = 0;
%! bond_struct.notional_at_start        = false;
%! bond_struct.notional_at_end          = true;
%! bond_struct.prepayment_flag          = false;
%! [ret_dates ret_values ret_int ret_princ accrued_interest] = rollout_structured_cashflows('31-Dec-2015','base',bond_struct);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_dates,[90,274,455,639,820,1004,1185,1369,1551,1735,1916,2100],0.000000001);
%! assert(ret_values,[1.0595890411,1.0712328767,1.0537671233,1.0712328767,1.0537671233,1.0712328767,1.0537671233,1.0712328767,1.0595890411,1.0712328767,1.0537671233,101.0712328767],0.000000001);
%! assert(accrued_interest,0.535616438356163,0.0000001);

%!test
%! bond_struct=struct();
%! bond_struct.sub_type                 = 'FAB';
%! bond_struct.issue_date               = '12-Mar-2016';
%! bond_struct.maturity_date            = '12-Feb-2020';
%! bond_struct.compounding_type         = 'simple';
%! bond_struct.compounding_freq         = 1  ;
%! bond_struct.term                     = 3   ;
%! bond_struct.day_count_convention     = 'act/act';
%! bond_struct.basis                    = 0;
%! bond_struct.notional                 = 34300000 ;
%! bond_struct.coupon_rate              = 0.02147; 
%! bond_struct.coupon_generation_method = 'backward' ;
%! bond_struct.business_day_rule        = 0 ;
%! bond_struct.business_day_direction   = 1  ;
%! bond_struct.enable_business_day_rule = 0;
%! bond_struct.spread                   = 0.00 ;
%! bond_struct.long_first_period        = false;
%! bond_struct.long_last_period         = false;
%! bond_struct.last_reset_rate          = 0.0000000;
%! bond_struct.fixed_annuity            = 0;
%! bond_struct.in_arrears               = 0;
%! bond_struct.notional_at_start        = false;
%! bond_struct.notional_at_end          = true;
%! bond_struct.prepayment_flag          = false;
%! bond_struct.principal_payment        = 147000.00;
%! bond_struct.use_principal_pmt        = 1;
%! [ret_dates ret_values ret_int ret_princ] = rollout_structured_cashflows('31-Mar-2016','base',bond_struct);
%! assert(ret_values,ret_int + ret_princ,sqrt(eps))
%! assert(ret_values(1:3),[269736.833333330,331317.955519128,330524.621420768],sqrt(eps))
%! assert(ret_values(end),32268464.028369263,sqrt(eps))