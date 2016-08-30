function s = set (capfloor, varargin)
  s = capfloor;
  if (length (varargin) < 2 || rem (length (varargin), 2) ~= 0)
    error ('set: expecting property/value pairs');
  end
  while (length (varargin) > 1)
    prop = varargin{1};
    prop = lower(prop);
    val = varargin{2};
    varargin(1:2) = [];
    % ====================== set value_mc: if isvector -> append to existing vector / matrix, if ismatrix -> replace existing value
    if (ischar (prop) && strcmp (prop, 'value_mc'))   
      if (isvector (val) && isreal (val))
        tmp_vector = [s.value_mc];
        if ( rows(tmp_vector) > 0 ) % appending vector to existing vector
            if ( rows(tmp_vector) == rows(val) )
                s.value_mc = [tmp_vector, val];
            else
                error ('set: expecting equal number of rows')
            end
        else    % setting vector
            s.value_mc = val;
        end      
      elseif (ismatrix(val) && isreal(val)) % replacing value_mc matrix with new matrix
        s.value_mc = val;
      else
        if ( isempty(val))
            s.value_mc = [];
        else
            error ('set: expecting the value to be a real vector');
        end
      end
    % ====================== set timestep_mc: appending or setting timestep vector ======================
    elseif (ischar (prop) && strcmp (prop, 'timestep_mc'))   
      if (iscell(val) && length(val) == 1)
        tmp_cell = s.timestep_mc;
        if ( length(tmp_cell) > 0 ) % appending vector to existing vector
            s.timestep_mc{length(tmp_cell) + 1} = char(val);
        else    % setting vector
            s.timestep_mc = val;
        end      
      elseif (iscell(val) && length(val) > 1) % replacing timestep_mc cell vector with new vector
        s.timestep_mc = val;
      elseif ( ischar(val) )
        tmp_cell = s.timestep_mc;
        if ( length(tmp_cell) > 0 ) % appending vector to existing vector
            s.timestep_mc{length(tmp_cell) + 1} = char(val);
        else    % setting vector
            s.timestep_mc = cellstr(val);
        end 
      else
        error ('set: expecting the cell value to be a cell vector');
      end  
    % ====================== set value_stress ======================
    elseif (ischar (prop) && strcmp (prop, 'value_stress'))   
      if (isvector (val) && isreal (val))
        s.value_stress = val;
      else
        if ( isempty(val))
            s.value_stress = [];
        else
            error ('set: expecting the value to be a real vector');
        end
      end
    % ====================== set value_base ======================
    elseif (ischar (prop) && strcmp (prop, 'value_base'))   
      if (isvector (val) && isreal (val))
        s.value_base = val;
      else
        error ('set: expecting the value to be a real vector');
      end 
    % ====================== set cf_values_stress ======================
    elseif (ischar (prop) && strcmp (prop, 'cf_values_stress'))   
      if (isreal (val))
        s.cf_values_stress = val;
      else
        error ('set: expecting the cf stress value to be real ');
      end
    % ====================== set cf_values ======================
    elseif (ischar (prop) && strcmp (prop, 'cf_values'))   
      if (isvector (val) && isreal (val))
        s.cf_values = val;
      else
        error ('set: expecting the base values to be a real vector');
      end
    % ====================== set cf_dates ======================
    elseif (ischar (prop) && strcmp (prop, 'cf_dates'))   
      if (isvector (val) && isreal (val))
        s.cf_dates = val;
      else
        error ('set: expecting cf_dates to be a real vector');
      end 
    % ====================== set timestep_mc_cf: appending or setting timestep vector ======================
    elseif (ischar (prop) && strcmp (prop, 'timestep_mc_cf'))   
      if (iscell(val) && length(val) == 1)
        tmp_cell = s.timestep_mc_cf;
        if ( length(tmp_cell) > 0 ) % appending vector to existing vector
            s.timestep_mc_cf{length(tmp_cell) + 1} = char(val);
        else    % setting vector
            s.timestep_mc_cf = val;
        end      
      elseif (iscell(val) && length(val) > 1) % replacing timestep_mc_cf cell vector with new vector
        s.timestep_mc_cf = val;
      elseif ( ischar(val) )
        tmp_cell = s.timestep_mc_cf;
        if ( length(tmp_cell) > 0 ) % appending vector to existing vector
            s.timestep_mc_cf{length(tmp_cell) + 1} = char(val);
        else    % setting vector
            s.timestep_mc_cf = cellstr(val);
        end 
      else
        error ('set: expecting the cell value to be a cell vector');
      end
    % ====================== set name ======================
    elseif (ischar (prop) && strcmp (prop, 'name'))   
      if (ischar (val) )
        s.name = strtrim(val);
      else
        error ('set: expecting the value to be a char');
      end
    % ====================== set id ======================
    elseif (ischar (prop) && strcmp (prop, 'id'))   
      if (ischar(val))
        s.id = strtrim(val);
      else
        error ('set: expecting the value to be a char');
      end
    % ====================== set sub_type ======================
    elseif (ischar (prop) && strcmp (prop, 'sub_type'))   
      if (ischar (val))
        s.sub_type = strtrim(val);
      else
        error ('set: expecting the value to be a char');
      end   
    % ====================== set asset_class ======================
    elseif (ischar (prop) && strcmp (prop, 'asset_class'))   
      if (ischar (val))
        s.asset_class = strtrim(val);
      else
        error ('set: expecting the value to be a char');
      end 
    % ====================== set currency ======================
    elseif (ischar (prop) && strcmp (prop, 'currency'))   
      if (ischar (val))
        s.currency = strtrim(val);
      else
        error ('set: expecting the value to be a char');
      end 
    % ====================== set description ======================
    elseif (ischar (prop) && strcmp (prop, 'description'))   
      if (ischar (val))
        s.description = strtrim(val);
      else
        error ('set: expecting the value to be a char');
      end
    % ====================== set maturity_date ======================
    elseif (ischar (prop) && strcmp (prop, 'maturity_date'))   
      if (ischar (val))
        s.maturity_date = datestr(strtrim(val),1);
      elseif ( isnumeric(val))
        s.maturity_date = datestr(val);
      else
        error ('set: expecting maturity_date to be a char or integer');
      end 
    % ====================== set issue_date ======================
    elseif (ischar (prop) && strcmp (prop, 'issue_date'))   
      if (ischar (val))
        s.issue_date = datestr(strtrim(val),1);
      elseif ( isnumeric(val))
        s.issue_date = datestr(val);
      else
        error ('set: expecting issue_date to be a char or integer');
      end  
    % ====================== set discount_curve  ======================
    elseif (ischar (prop) && strcmp (prop, 'discount_curve'))   
      if (ischar (val))
        s.discount_curve = strtrim(val);
      else
        error ('set: expecting the value to be a char');
      end
   % ====================== set reference_curve  ======================
    elseif (ischar (prop) && strcmp (prop, 'reference_curve'))   
      if (ischar (val))
        s.reference_curve = strtrim(val);
      else
        error ('set: expecting reference_curve to be a char');
      end 
    % ====================== set model ======================
    elseif (ischar (prop) && strcmp (prop, 'model'))   
      if (ischar (val))
        s.model = strtrim(val);
      else
        error ('set: expecting model to be a char');
      end  
    % ====================== set vola_surface ======================
    elseif (ischar (prop) && strcmp (prop, 'vola_surface'))   
      if (ischar (val))
        s.vola_surface = strtrim(val);
      else
        error ('set: expecting vola_surface to be a char');
      end
    % ====================== set spread ======================
    elseif (ischar (prop) && strcmp (prop, 'spread'))   
      if (isnumeric (val) && isreal (val))
        s.spread = val;
      else
        error ('set: expecting spread to be a real number');
      end
    % ====================== set strike ======================
    elseif (ischar (prop) && strcmp (prop, 'strike'))   
      if (isnumeric (val) && isreal (val))
        s.strike = val;
      else
        error ('set: expecting strike rate to be a real number');
      end
    % ====================== set compounding_freq  ======================
    elseif (ischar (prop) && strcmp (prop, 'compounding_freq'))   
      if (isreal (val))
        s.compounding_freq  = val;
      elseif (ischar(val))
        s.compounding_freq  = val;
      else
        error ('set: expecting compounding_freq to be a real number or char');
      end       
    % ====================== set day_count_convention ======================
    elseif (ischar (prop) && strcmp (prop, 'day_count_convention'))   
      if (ischar (val))
        s.day_count_convention = strtrim(val);
      else
        error ('set: expecting day_count_convention to be a char');
      end 
    % ====================== set compounding_type ======================
    elseif (ischar (prop) && strcmp (prop, 'compounding_type'))   
      if (ischar (val))
        s.compounding_type = strtrim(val);
      else
        error ('set: expecting compounding_type to be a char');
      end
    % ====================== set coupon_generation_method  ====================
    elseif (ischar (prop) && strcmp (prop, 'coupon_generation_method'))   
      if (ischar (val))
        s.coupon_generation_method = strtrim(val);
      else
        error ('set: expecting coupon_generation_method to be a char');
      end 
    % ====================== set notional ======================
    elseif (ischar (prop) && strcmp (prop, 'notional'))   
      if (isnumeric (val) && isreal (val))
        s.notional = val;
      else
        error ('set: expecting notional to be a real number');
      end 
    % ====================== set business_day_rule ======================
    elseif (ischar (prop) && strcmp (prop, 'business_day_rule'))   
      if (isnumeric (val) && isreal (val))
        s.business_day_rule = val;
      else
        error ('set: expecting business_day_rule to be a real number');
      end 
    % ====================== set business_day_direction ======================
    elseif (ischar (prop) && strcmp (prop, 'business_day_direction'))   
      if (isnumeric (val) && isreal (val))
        s.business_day_direction = val;
      else
        error ('set: expecting business_day_direction to be a real number');
      end 
    % ====================== set enable_business_day_rule ======================
    elseif (ischar (prop) && strcmp (prop, 'enable_business_day_rule'))   
      if (isnumeric (val) && isreal (val))
        s.enable_business_day_rule = logical(val);
      elseif ( ischar(val))
        if ( strcmp('false',lower(val)))
            s.enable_business_day_rule = logical(0);
        elseif ( strcmp('true',lower(val)))
            s.enable_business_day_rule = logical(1);
        else
            printf('WARNING: Unknown val: >>%s<<. Setting enable_business_day_rule to false.',val);
            s.enable_business_day_rule = logical(0);
        end
      elseif ( islogical(val))
        s.enable_business_day_rule = val;
      else
        error ('set: expecting enable_business_day_rule to be a real number or true/false');
      end
    % ====================== set convex_adj ======================
    elseif (ischar (prop) && strcmp (prop, 'convex_adj'))   
      if (isnumeric (val) && isreal (val))
        s.convex_adj = logical(val);
      elseif ( ischar(val))
        if ( strcmpi('false',lower(val)))
            s.convex_adj = logical(0);
        elseif ( strcmpi('true',lower(val)))
            s.convex_adj = logical(1);
        else
            printf('WARNING: Unknown val: >>%s<<. Setting convex_adj to false.',val);
            s.convex_adj = logical(0);
        end
      elseif ( islogical(val))
        s.convex_adj = val;
      else
        error ('set: expecting convex_adj to be a real number or true/false');
      end
    % ====================== set long_first_period ======================
    elseif (ischar (prop) && strcmp (prop, 'long_first_period'))   
      if (isnumeric (val) && isreal (val))
        s.long_first_period = logical(val);
      elseif ( ischar(val))
        if ( strcmp('false',lower(val)))
            s.long_first_period = logical(0);
        elseif ( strcmp('true',lower(val)))
            s.long_first_period = logical(1);
        else
            printf('WARNING: Unknown val: >>%s<<. Setting long_first_period to false.',val);
            s.long_first_period = logical(0);
        end
      elseif ( islogical(val))
        s.long_first_period = val;    
      else
        error ('set: expecting long_first_period to be a real number');
      end 
    % ====================== set long_last_period ======================
    elseif (ischar (prop) && strcmp (prop, 'long_last_period'))   
      if (isnumeric (val) && isreal (val))
        s.long_last_period = logical(val);
      elseif ( ischar(val))
        if ( strcmp('false',lower(val)))
            s.long_last_period = logical(0);
        elseif ( strcmp('true',lower(val)))
            s.long_last_period = logical(1);
        else
            printf('WARNING: Unknown val: >>%s<<. Setting long_last_period to false.',val);
            s.long_last_period = logical(0);
        end
      elseif ( islogical(val))
        s.long_last_period = val; 
      else
        error ('set: expecting long_last_period to be a real number');
      end 
    % ====================== set last_reset_rate ======================
    elseif (ischar (prop) && strcmp (prop, 'last_reset_rate'))   
      if (isnumeric (val) && isreal (val))
        s.last_reset_rate = val;
      else
        error ('set: expecting last_reset_rate to be a real number');
      end 
    % ====================== set mod_duration ======================
    elseif (ischar (prop) && strcmp (prop, 'mod_duration'))   
      if (isnumeric (val) && isreal (val))
        s.mod_duration = val;
      else
        error ('set: expecting mod_duration to be a real number');
      end
    % ====================== set mac_duration ======================
    elseif (ischar (prop) && strcmp (prop, 'mac_duration'))   
      if (isnumeric (val) && isreal (val))
        s.mac_duration = val;
      else
        error ('set: expecting mac_duration to be a real number');
      end      
    % ====================== set eff_duration ======================
    elseif (ischar (prop) && strcmp (prop, 'eff_duration'))   
      if (isnumeric (val) && isreal (val))
        s.eff_duration = val;
      else
        error ('set: expecting eff_duration to be a real number');
      end      
    % ====================== set eff_convexity ======================
    elseif (ischar (prop) && strcmp (prop, 'eff_convexity'))   
      if (isnumeric (val) && isreal (val))
        s.eff_convexity = val;
      else
        error ('set: expecting eff_convexity to be a real number');
      end      
    % ====================== set dv01 ======================
    elseif (ischar (prop) && strcmp (prop, 'dv01'))   
      if (isnumeric (val) && isreal (val))
        s.dv01 = val;
      else
        error ('set: expecting dv01 to be a real number');
      end   
    % ====================== set pv01 ======================
    elseif (ischar (prop) && strcmp (prop, 'pv01'))   
      if (isnumeric (val) && isreal (val))
        s.pv01 = val;
      else
        error ('set: expecting pv01 to be a real number');
      end      
    % ====================== set dollar_duration ======================
    elseif (ischar (prop) && strcmp (prop, 'dollar_duration'))   
      if (isnumeric (val) && isreal (val))
        s.dollar_duration = val;
      else
        error ('set: expecting dollar_duration to be a real number');
      end
    % ====================== set spread_duration ======================
    elseif (ischar (prop) && strcmp (prop, 'spread_duration'))   
      if (isnumeric (val) && isreal (val))
        s.spread_duration = val;
      else
        error ('set: expecting spread_duration to be a real number');
      end
    % ====================== set in_arrears ======================
    elseif (ischar (prop) && strcmp (prop, 'in_arrears'))   
      if (isnumeric (val) && isreal (val))
        s.in_arrears = logical(val);
      elseif ( ischar(val))
        if ( strcmp('false',lower(val)))
            s.in_arrears = logical(0);
        elseif ( strcmp('true',lower(val)))
            s.in_arrears = logical(1);
        else
            printf('WARNING: Unknown val: >>%s<<. Setting in_arrears to false.',val);
            s.in_arrears = logical(0);
        end
      elseif ( islogical(val))
        s.in_arrears = val;
      else
        error ('set: expecting in_arrears to be a real number');
      end 
    % ====================== set notional_at_start ======================
    elseif (ischar (prop) && strcmp (prop, 'notional_at_start'))   
      if (isnumeric (val) && isreal (val))
        s.notional_at_start = logical(val);
      elseif ( ischar(val))
        if ( strcmp('false',lower(val)))
            s.notional_at_start = logical(0);
        elseif ( strcmp('true',lower(val)))
            s.notional_at_start = logical(1);
        else
            printf('WARNING: Unknown val: >>%s<<. Setting notional_at_start to false.',val);
            s.notional_at_start = logical(0);
        end
      elseif ( islogical(val))
        s.notional_at_start = val;
      else
        error ('set: expecting notional_at_start to be a real number');
      end 
    % ====================== set notional_at_end  ======================
    elseif (ischar (prop) && strcmp (prop, 'notional_at_end'))   
      if (isnumeric (val) && isreal (val))
        s.notional_at_end = logical(val);
      elseif ( ischar(val))
        if ( strcmp('false',lower(val)))
            s.notional_at_end = logical(0);
        elseif ( strcmp('true',lower(val)))
            s.notional_at_end = logical(1);
        else
            printf('WARNING: Unknown val: >>%s<<. Setting notional_at_end to false.',val);
            s.notional_at_end = logical(0);
        end
      elseif ( islogical(val))
        s.notional_at_end = val;
      else
        error ('set: expecting notional_at_end to be a real number');
      end
    % ====================== set term ======================
    elseif (ischar (prop) && strcmp (prop, 'term'))   
      if (isnumeric (val) && isreal (val))
        s.term = val;
      else
        error ('set: expecting term to be a real number');
      end 
    else
      error ('set: invalid property of capfloor class:  >>%s<< \n',prop);
    end
  end
end