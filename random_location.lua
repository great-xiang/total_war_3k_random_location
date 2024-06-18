--author:大相great-xiang,date:2024.06.17
random_location = {
    target_factions = {},
    capital_regions = {},
    minor_regions = {},
    pass_regions = {
        "3k_dlc06_gu_pass",
        "3k_dlc06_hangu_pass",
        "3k_dlc06_hulao_pass",
        "3k_dlc06_jiameng_pass",
        "3k_dlc06_kui_pass",
        "3k_dlc06_qi_pass",
        "3k_dlc06_san_pass",
        "3k_dlc06_tong_pass",
        "3k_dlc06_wu_pass"
    },

    prohibited_regions = {
        ["3k_main_campaign_map"] = {
            "3k_main_changan_capital",
            "3k_main_changan_resource_1",
            "3k_main_luoyang_capital",
            "3k_main_hanzhong_resource_1",
            "3k_dlc06_san_pass",
            "3k_dlc06_wu_pass",
            "3k_dlc06_tong_pass",
            "3k_main_yizhou_island_capital",
            "3k_main_yizhou_island_resource_1"
        },

        ["3k_dlc05_start_pos"] = {
            "3k_main_changan_capital",
            "3k_main_changan_resource_1",
            "3k_main_luoyang_capital",
            "3k_main_luoyang_resource_1",
            "3k_main_hanzhong_resource_1",
            "3k_dlc06_san_pass",
            "3k_dlc06_wu_pass",
            "3k_dlc06_tong_pass",
            "3k_dlc06_hangu_pass"
        },

        ["8p_start_pos"] = {
            "3k_main_luoyang_capital",
            "3k_dlc06_shangdang_resource_2",
            "3k_main_yingchuan_capital"
        }
    },

    empire_factions = {
        ["3k_main_campaign_map"] = "3k_main_faction_han_empire",
        ["3k_dlc05_start_pos"] = "3k_main_faction_han_empire",
        ["8p_start_pos"] = "ep_faction_empire_of_jin"
    },

    rebel_factions = {
        ["3k_main_campaign_map"] = "3k_main_faction_yellow_turban_generic",
        ["3k_dlc05_start_pos"] = "3k_main_faction_yellow_turban_generic",
        ["8p_start_pos"] = "ep_factions_shadow_rebels"
    },

    skip_factions = {
        ["3k_main_campaign_map"] = "3k_main_faction_dong_zhuo",
        ["3k_dlc05_start_pos"] = "3k_main_faction_dong_zhuo",
        ["8p_start_pos"] = "ep_faction_duke_of_lanling"
    },

    invalid_factions = {
        "3k_dlc04_faction_rebels",
        "3k_dlc06_faction_nanman_rebels",
        "3k_dlc07_faction_shanyue_rebels",
        "3k_dlc07_faction_shanyue_rebels_separatists",
        "3k_main_faction_han_empire",
        "3k_main_faction_han_empire_separatists",
        "3k_main_faction_rebels",
        "3k_main_faction_yellow_turban_generic",
        "ep_faction_empire_of_jin",
        "ep_faction_empire_of_jin_separatists",
        "ep_faction_rebels",
        "ep_factions_shadow_rebels"
    }
}

cm:add_first_tick_callback(function() random_location:Initialise() end);
function random_location:Initialise()
    core:add_listener("RandomLocationEventTrigger", "FactionTurnStart",
        function(context) return context:query_model():turn_number() == 1; end,
        function()
            --------------------------------------------------------
            -- set give away faction, rebel faction and skip faction
            local empire_faction = self.empire_factions[cm:query_model():campaign_name()];
            local rebel_faction = self.rebel_factions[cm:query_model():campaign_name()];
            local skip_faction = self.skip_factions[cm:query_model():campaign_name()];
            -- ModLog("empire_faction: " .. empire_faction);
            -- ModLog("rebel_faction: " .. rebel_faction);
            -- ModLog("skip_faction: " .. skip_faction);
            --  go through factions and prepare armies
            cm:query_model():world():faction_list():foreach(function(filter_faction)
                if not table.contains(self.invalid_factions, filter_faction:name()) and skip_faction ~= filter_faction:name() 
                and not filter_faction:is_dead()then
                    table.insert(self.target_factions, filter_faction:name())
                end
                if not filter_faction:is_dead() and filter_faction:military_force_list():is_empty() then
                    campaign_invasions:create_invasion(filter_faction:name(), filter_faction:capital_region():name(), 2,
                        false);
                end;
            end)

            --  go through region
            cm:query_model():world():region_manager():region_list():filter(function(filter_region)
                return not table.contains(self.prohibited_regions[cm:query_model():campaign_name()], filter_region:name())
            end):foreach(function(filter_region)
                cm:modify_model():get_modify_region(filter_region):settlement_gifted_as_if_by_payload(cm:modify_faction(
                    empire_faction));
                if not table.contains(self.pass_regions, filter_region:name()) then
                    if filter_region:is_province_capital() then
                        table.insert(self.capital_regions, filter_region:name());
                    else
                        table.insert(self.minor_regions, filter_region:name());
                    end;
                end;
            end);

            -- allocate regions for factions
            -- ModLog("allocate capital_regions for factions")
            for k, faction_key in ipairs(self.target_factions) do
                -- ModLog("Processing faction: " .. tostring(faction_key))
                self:SetRandomRegion(faction_key, empire_faction);
                self:MoveArmy(faction_key);
            end;


            -- Allocate entire province to factions
            -- ModLog("Allocating entire commandery to factions")
            for k, faction_key in ipairs(self.target_factions) do
                -- ModLog("Processing faction: " .. tostring(faction_key))
                local faction = self:get_faction_by_name(faction_key)
                -- find captial's resources
                local resource_points = {}
                cm:query_model():world():region_manager():region_list():foreach(function(region)
                    if region:province_name() == faction:capital_region():province_name() then
                        table.insert(resource_points, region:name())
                    end
                end)
                for _, minor_region_name in pairs(resource_points) do
                    if table.contains(self.minor_regions, minor_region_name) then
                        -- ModLog("Assigning region " .. minor_region_name .. " to faction " .. faction_key)
                        cm:modify_region(cm:query_region(minor_region_name)):settlement_gifted_as_if_by_payload(
                            cm:modify_faction(faction_key))
                        self:remove_table_value(self.minor_regions, minor_region_name)
                    end
                end
            end
            
            -- give 2/3 region to rebel region
            cm:query_faction(empire_faction):region_list():foreach(function(filter_region)
                local rebel_check = cm:random_int(1, 3);
                if rebel_check > 1 and filter_region:name() ~= "3k_main_luoyang_capital" then
                    cm:modify_region(filter_region):settlement_gifted_as_if_by_payload(cm:modify_faction(rebel_faction));
                end;
            end);

            -- disperse give faction/ rebel faction 's army
            local public_factions = {};
            table.insert(public_factions, empire_faction);
            table.insert(public_factions, rebel_faction);
            for k, public_faction in ipairs(public_factions) do
                local query_faction = cm:query_faction(public_faction);
                for i = 0, query_faction:military_force_list():num_items() - 1 do
                    local filter_force = query_faction:military_force_list():item_at(i)
                    local picked_region_id = cm:random_int(1, query_faction:region_list():num_items());
                    local picked_region = query_faction:region_list():item_at(picked_region_id - 1);
                    local region_x = picked_region:settlement():logical_position_x() + math.random(1200) / 100 - 6;
                    local region_y = picked_region:settlement():logical_position_y() + math.random(1200) / 100 - 6;
                    if not misc:is_transient_character(filter_force:general_character())
                        and not filter_force:unit_list():is_empty() then
                        local force_general = filter_force:general_character();
                        local found_pos, x, y = query_faction:get_valid_spawn_location_near(region_x, region_y, 10,
                            false);
                        if not found_pos then
                            found_pos, x, y = query_faction:get_valid_spawn_location_in_region(picked_region:name(),
                                false);
                        end;
                        if found_pos then
                            cm:modify_character(force_general):teleport_to(x, y);
                        end;
                    end;
                end;
            end;

            -- RemoveMission
            random_location:RemoveMission();

            -- reset camera
            local query_settlement = cm:query_faction(cm:get_human_factions()[1]):capital_region():settlement();
            local x, y, d, b, h = cm:get_camera_position();
            local new_capital_x = query_settlement:display_position_x();
            local new_capital_y = query_settlement:display_position_y();
            local duration = 0.2 * distance_squared(x, y, new_capital_x, new_capital_y);
            duration = math.min(duration, 5);
            if duration > 0 then
                cm:scroll_camera_from_current(duration, true, { new_capital_x, new_capital_y, 8, b, 10 });
            end;
            -- ModLog("reset camera done!")
            ---------------------------------------------------------
        end, false);
end

function random_location:SetRandomRegion(faction_key, empire_faction)
    -- ModLog("Capital regions count: " .. #self.capital_regions)
    -- ModLog("Minor regions count: " .. #self.minor_regions)
    if not table.is_empty(self.capital_regions) then
        target_region = self.capital_regions[cm:random_int(1, #self.capital_regions)];
        self:remove_table_value(self.capital_regions, target_region);
    elseif not table.is_empty(self.minor_regions) then
        target_region = self.minor_regions[cm:random_int(1, #self.minor_regions)];
        self:remove_table_value(self.minor_regions, target_region);
    else
        target_region = nil
    end
    if target_region then
        cm:modify_region(target_region):settlement_gifted_as_if_by_payload(cm:modify_faction(faction_key));
        -- ModLog("give " .. target_region .. " to " .. empire_faction);
    else
        -- ModLog("Error: No regions available.");
    end
end

function random_location:MoveArmy(faction_key)
    local filter_faction = cm:query_faction(faction_key);
    local query_capital = filter_faction:capital_region();
    for i = 0, filter_faction:military_force_list():num_items() - 1 do
        local filter_force = filter_faction:military_force_list():item_at(i);
        local region_x = query_capital:settlement():logical_position_x() + math.random(1200) / 100 - 6;
        local region_y = query_capital:settlement():logical_position_y() + math.random(1200) / 100 - 6;
        if not misc:is_transient_character(filter_force:general_character())
            and not filter_force:unit_list():is_empty() then
            local force_general = filter_force:general_character();
            local found_pos, x, y = filter_faction:get_valid_spawn_location_near(region_x, region_y, 10, false);
            if not found_pos then
                found_pos, x, y = filter_faction:get_valid_spawn_location_in_region(query_capital:name(), false);
            end;
            if found_pos then
                cm:modify_character(force_general):teleport_to(x, y);
            end;
        end;
    end;
end

function random_location:RemoveMission()
    -- Assuming player's keys,Selecting the first faction key,Passing faction key to modify_faction
    modify_filter_faction = cm:modify_faction(cm:get_human_factions()[1]);
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_kong_rong_destroy_yuan_shao");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_kong_rong_destroy_yuan_tan");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_liu_bei_destroy_lu_bu");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_liu_bei_destroy_yuan_shu");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_yuan_shao_destroy_faction");
    modify_filter_faction:cancel_custom_mission("3k_dlc04_main_tutorial_liu_chong_defeat_army_mission");
    modify_filter_faction:cancel_custom_mission("3k_dlc04_tutorial_liu_bei_defeat_army_mission");
    modify_filter_faction:cancel_custom_mission("3k_dlc04_tutorial_liu_bei_defeat_army_1_mission");
    modify_filter_faction:cancel_custom_mission("3k_dlc04_tutorial_liu_bei_defeat_army_2_mission");
    modify_filter_faction:cancel_custom_mission("3k_dlc04_tutorial_liu_bei_defeat_army_3_mission");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_gongsun_zan_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_kong_rong_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_liu_bei_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_liu_biao_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_zhang_yan_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_dlc05_tutorial_mission_zheng_jiang_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_cao_cao_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_dong_zhuo_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_gongsun_zan_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_kong_rong_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_liu_bei_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_liu_biao_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_ma_teng_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_sun_jian_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_tao_qian_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_yuan_shao_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_yuan_shu_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_zhang_yan_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_main_tutorial_mission_zheng_jiang_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_ytr_tutorial_mission_gong_du_1_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_ytr_tutorial_mission_he_yi_1_defeat_army");
    modify_filter_faction:cancel_custom_mission("3k_ytr_tutorial_mission_huang_shao_1_defeat_army");
    modify_filter_faction:cancel_custom_mission("ep_mission_introduction_destroy_army_sima_yue");
    modify_filter_faction:cancel_custom_mission("ep_mission_introduction_destroy_army_sima_ying");
    modify_filter_faction:cancel_custom_mission("ep_mission_introduction_destroy_army_sima_yong");
    modify_filter_faction:cancel_custom_mission("ep_mission_introduction_destroy_army_sima_lun");
    modify_filter_faction:cancel_custom_mission("ep_mission_introduction_destroy_army_sima_wei");
    modify_filter_faction:cancel_custom_mission("ep_mission_introduction_destroy_army_sima_jiong");
    modify_filter_faction:cancel_custom_mission("ep_mission_introduction_destroy_army_sima_ai");
    modify_filter_faction:cancel_custom_mission("ep_mission_introduction_destroy_army_sima_liang");

    modify_filter_faction:complete_custom_mission("3k_dlc04_main_tutorial_liu_chong_capture_settlement_mission");
    modify_filter_faction:complete_custom_mission("3k_dlc05_tutorial_mission_kong_rong_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_dlc05_tutorial_mission_liu_bei_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_dlc05_tutorial_mission_yan_baihu_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_dlc05_tutorial_mission_zheng_jiang_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_cao_cao_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_dong_zhuo_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_gongsun_zan_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_kong_rong_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_liu_bei_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_liu_biao_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_ma_teng_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_sun_jian_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_tao_qian_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_yuan_shao_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_yuan_shu_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_zhang_yan_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_zheng_jiang_capture_settlement");
    modify_filter_faction:complete_custom_mission("3k_ytr_tutorial_mission_gong_du_1_capture_region");
    modify_filter_faction:complete_custom_mission("3k_ytr_tutorial_mission_huang_shao_1_capture_region");
    modify_filter_faction:complete_custom_mission("3k_ytr_tutorial_mission_he_yi_1_capture_region");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_liu_bei_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_yuan_shao_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_ma_teng_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_cao_cao_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_zhang_yan_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_liu_biao_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_dong_zhuo_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_sun_jian_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_yuan_shu_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_gongsun_zan_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_zheng_jiang_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_kong_rong_construct_building");
    modify_filter_faction:complete_custom_mission("3k_main_tutorial_mission_tao_qian_construct_building");
    modify_filter_faction:complete_custom_mission("3k_dlc05_tutorial_mission_ma_teng_construct_building");
    modify_filter_faction:complete_custom_mission("3k_dlc05_tutorial_mission_yan_baihu_construct_building");
    modify_filter_faction:complete_custom_mission("3k_dlc05_tutorial_mission_zheng_jiang_construct_building");
    modify_filter_faction:complete_custom_mission("3k_dlc06_progression_nanman_destroy_faction_mission");
    -- ModLog("RemoveMission Done!");
end

function random_location:remove_table_value(tb, value)
    if tb ~= nil and next(tb) ~= nil then
        for i = #tb, 1, -1 do
            if tb[i] == value then
                table.remove(tb, i)
            end
        end
    end
end

function random_location:get_faction_by_name(faction_name)
    local target_faction = nil
    cm:query_model():world():faction_list():foreach(function(faction)
        if faction:name() == faction_name then
            target_faction = faction
        end
    end)
    return target_faction
end
