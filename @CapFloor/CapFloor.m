classdef CapFloor < Instrument
   
    properties   % All properties of Class CapFloor with default values
        issue_date = '01-Jan-1900';
        maturity_date = '';
        compounding_type = 'cont';
        compounding_freq = 1;  
        term = 12;               
        day_count_convention = 'act/365';
        notional = 0;                 
        coupon_generation_method = 'backward';
        business_day_rule = 0; 
        business_day_direction = 1;
        enable_business_day_rule = 0;
        spread = 0.0;       
        long_first_period = 0;  
        long_last_period = 0;   
        last_reset_rate = 0.00001;
        discount_curve = 'IR_EUR';
        reference_curve = 'IR_EUR';
        ir_shock   = 0.01;      % shock used for calculation of effective duration
		vola_shock = 0.0001;	% shock used for calculation of vega
        in_arrears = 0;
        notional_at_start = 0; 
        notional_at_end = 0;
        coupon_rate = 0.0;
        prorated = true; % Bool: true means deposit method 
        %  (adjust cash flows for leap year), false = bond method (fixed coupon)
                                %(mark to market) successful            
        vola_surface = 'RF_VOLA_IR_EUR';
        strike = 0.005;
        convex_adj = true;      % flag for using convex adj. for forward rates
        % attributes for CMS Floating and Fixed Legs
        cms_model               = 'Black'; % volatility model [Black, normal]
        cms_convex_model        = 'Hull'; % Model for calculating convexity adj.
        cms_sliding_term        = 1825; % sliding term of CMS float leg in days
        cms_term                = 365; % term of CMS
        cms_spread              = 0.0; % spread of CMS
        cms_comp_type           = 'simple'; % CMS compounding type
        vola_spread             = 0.0;
		% Inflation Linked bond specific attributes
		cpi_index				= ''; % Consumer Price Index
		infl_exp_curve			= ''; % Inflation Expectation Curve
		cpi_historical_curve	= ''; % Curve with historical values for CPI
		infl_exp_lag			= ''; % inflation expectation lag (in months)
		use_indexation_lag		= false; % Bool: true -> use infl_exp_lag
		calibration_flag = 1;       % BOOL: if true, no calibration will be done
    end
   
    properties (SetAccess = private)
        convexity = 0.0;
        eff_convexity = 0.0;
        dollar_convexity = 0.0;
        cf_dates = [];
        cf_values = [];
        cf_values_mc  = [];
        cf_values_stress = [];
        timestep_mc_cf = {};
        ytm = 0.0;
        soy = 0.0;      % spread over yield
        sub_type = 'CAP';
        mac_duration = 0.0;
        mod_duration = 0.0;
        eff_duration = 0.0;
		vega = 0.0;
		theta = 0.0;
        spread_duration = 0.0;
        dollar_duration = 0.0;
        dv01 = 0.0;
        pv01 = 0.0;
        accrued_interest = 0.0;
        basis = 3;
        model = 'Black';
        CapFlag = true;
    end

   methods
      function b = CapFloor(tmp_name)
        if nargin < 1
            name  = 'CAP_TEST';
            id    = 'CAP_TEST';           
        else
            name  = tmp_name;
            id    = name;
        end
        description = 'Cap test instrument';
        value_base = 1;      
        currency = 'EUR';
        asset_class = 'Derivative';   
        % use constructor inherited from Class Instrument
        b = b@Instrument(name,id,description,'capfloor',currency,value_base, ...
                        asset_class); 
      end 
      
      function disp(b)
         disp@Instrument(b)
         fprintf('sub_type: %s\n',b.sub_type);      
         fprintf('issue_date: %s\n',b.issue_date);
         fprintf('maturity_date: %s\n',b.maturity_date);      
         fprintf('strike: %f \n',b.strike);     
         fprintf('term: %f \n',b.term);      
         fprintf('notional: %f \n',b.notional);  
         fprintf('notional_at_start: %d \n',b.notional_at_start);
         fprintf('notional_at_end: %d \n',b.notional_at_end);          
         fprintf('reference_curve: %s\n',b.reference_curve);  
         fprintf('vola_surface: %s\n',b.vola_surface ); 
         fprintf('discount_curve: %s\n',b.discount_curve); 
         fprintf('compounding_type: %s\n',b.compounding_type);  
         fprintf('compounding_freq: %d\n',b.compounding_freq);    
         fprintf('day_count_convention: %s\n',b.day_count_convention); 
         fprintf('model: %s\n',b.model); 
         fprintf('convex_adj: %s\n',any2str(b.convex_adj)); 
         if ( regexpi(b.sub_type,'CMS'))
            fprintf('cms_model: %s\n',b.cms_model); 
            fprintf('cms_sliding_term: %s\n',any2str(b.cms_sliding_term)); 
            fprintf('cms_term: %s\n',any2str(b.cms_term)); 
            fprintf('cms_spread: %s\n',any2str(b.cms_spread)); 
            fprintf('cms_comp_type: %s\n',b.cms_comp_type); 
            fprintf('cms_convex_model: %s\n',b.cms_convex_model); 
         end 
		 if ( regexpi(b.sub_type,'INFL'))
            fprintf('cpi_index: %s\n',b.cpi_index); 
            fprintf('infl_exp_curve: %s\n',b.infl_exp_curve); 
            fprintf('cpi_historical_curve: %s\n',b.cpi_historical_curve); 
			fprintf('infl_exp_lag: %s\n',any2str(b.infl_exp_lag));
			fprintf('use_indexation_lag: %s\n',any2str(b.use_indexation_lag));
         end		 
         fprintf('ir_shock: %f \n',b.ir_shock);
		 fprintf('vola_spread: %f \n',b.vola_spread);
         fprintf('eff_duration: %f \n',b.eff_duration);
         fprintf('eff_convexity: %f \n',b.eff_convexity);
		 fprintf('vega: %f \n',b.vega);
		 fprintf('theta: %f \n',b.theta);
         % display all mc values and cf values
         cf_stress_rows = min(rows(b.cf_values_stress),5);
         [mc_rows mc_cols mc_stack] = size(b.cf_values_mc);
         % looping via all cf_dates if defined
         if ( length(b.cf_dates) > 0 )
            fprintf('CF dates:\n[ ');
            for (ii = 1 : 1 : length(b.cf_dates))
                fprintf('%d,',b.cf_dates(ii));
            end
            fprintf(' ]\n');
         end
         % looping via all cf base values if defined
         if ( length(b.cf_values) > 0 )
            fprintf('CF Base values:\n[ ');
            for ( kk = 1 : 1 : min(columns(b.cf_values),10))
                    fprintf('%f,',b.cf_values(kk));
                end
            fprintf(' ]\n');
         end   
          % looping via all stress rates if defined
         if ( rows(b.cf_values_stress) > 0 )
            tmp_cf_values = b.getCF('stress');
            fprintf('CF Stress values:\n[ ');
            for ( jj = 1 : 1 : min(rows(tmp_cf_values),5))
                for ( kk = 1 : 1 : min(columns(tmp_cf_values),10))
                    fprintf('%f,',tmp_cf_values(jj,kk));
                end
                fprintf(' ]\n');
            end
            fprintf('\n');
         end    
         % looping via first 3 MC scenario values
         for ( ii = 1 : 1 : mc_stack)
            if ( length(b.timestep_mc_cf) >= ii )
                fprintf('MC timestep: %s\n',b.timestep_mc_cf{ii});
                tmp_cf_values = b.getCF(b.timestep_mc_cf{ii});
                fprintf('Scenariovalue:\n[ ')
                for ( jj = 1 : 1 : min(rows(tmp_cf_values),5))
                    for ( kk = 1 : 1 : min(columns(tmp_cf_values),10))
                        fprintf('%f,',tmp_cf_values(jj,kk));
                    end
                    fprintf(' ]\n');
                end
                fprintf('\n');
            else
                fprintf('MC timestep cf not defined\n');
            end
         end
      end
      
      function obj = set.sub_type(obj,sub_type)
         if ~(strcmpi(sub_type,'CAP') || strcmpi(sub_type,'FLOOR') ...
                || strcmpi(sub_type,'CAP_CMS') || strcmpi(sub_type,'FLOOR_CMS') ...
				|| strcmpi(sub_type,'FLOOR_INFL') || strcmpi(sub_type,'CAP_INFL'))
            error('CapFloor sub_type must be either CAP(_CMS / _INFL), FLOOR(_CMS / _INFL)')
         end
         obj.sub_type = sub_type;
         if regexpi(sub_type,'CAP') 
            obj.CapFlag = true;
         else
            obj.CapFlag = false;
         end
      end % set.sub_type
      
      function obj = set.day_count_convention(obj,day_count_convention)
         obj.day_count_convention = day_count_convention;
         % Call superclass method to set basis
         obj.basis = Instrument.get_basis(obj.day_count_convention);
      end % set.day_count_convention
   end 
   
end 