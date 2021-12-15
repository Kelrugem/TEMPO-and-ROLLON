-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	-- EffectManager5E.applyOngoingDamageAdjustment = EffectManager2.applyOngoingDamageAdjustment;
	-- EffectManager5E.onEffectActorStartTurn = EffectManager2.onEffectActorStartTurn;
	
	EffectManager.setCustomOnEffectActorStartTurn(onEffectActorStartTurn);
end

function onEffectActorStartTurn(nodeActor, nodeEffect)
	local sEffName = DB.getValue(nodeEffect, "label", "");
	local aEffectComps = EffectManager.parseEffect(sEffName);
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
		-- Conditionals
		if rEffectComp.type == "IFT" then
			break;
		elseif rEffectComp.type == "IF" then
			local rActor = ActorManager.resolveActor(nodeActor);
			if not EffectManager5E.checkConditional(rActor, nodeEffect, rEffectComp.remainder) then
				break;
			end
		
		-- Ongoing damage and regeneration
		elseif rEffectComp.type == "DMGO" or rEffectComp.type == "TEMPO" or rEffectComp.type == "ROLLON" or rEffectComp.type == "REGEN" then
			local nActive = DB.getValue(nodeEffect, "isactive", 0);
			if nActive == 2 then
				if rEffectComp.type == "REGEN" then
					local rActor = ActorManager.resolveActor(nodeActor);
					if (ActorHealthManager.getWoundPercent(rActor) >= 1) then 
						break;
					end
				end
				DB.setValue(nodeEffect, "isactive", "number", 1);
			else
				applyOngoingDamageAdjustment(nodeActor, nodeEffect, rEffectComp);
			end
		-- KEL	
		-- Ongoing Save, copright Kent (if any), suggested by ScriedRaven (and adjusted a bit)
		elseif StringManager.contains(Extension.getExtensions(), "5E - Ongoing Save Effects") and rEffectComp.type == "SAVEO" then
			local nActive = DB.getValue(nodeEffect, "isactive", 0);
			if nActive == 2 then
				DB.setValue(nodeEffect, "isactive", "number", 1);
			else
				EffectManagerOSE.applyOngoingSaveAdjustment(nodeActor, nodeEffect, rEffectComp);
			end
		-- END
		-- NPC power recharge
		elseif rEffectComp.type == "RCHG" then
			local nActive = DB.getValue(nodeEffect, "isactive", 0);
			if nActive == 2 then
				DB.setValue(nodeEffect, "isactive", "number", 1);
			else
				EffectManager5E.applyRecharge(nodeActor, nodeEffect, rEffectComp);
			end
		end
	end
end

function applyOngoingDamageAdjustment(nodeActor, nodeEffect, rEffectComp)
	if rEffectComp.type == "ROLLON" then
		-- Debug.console(rEffectComp.remainder);
		-- local nodeTable = TableManager.findTable(rEffectComp.remainder);
		-- if nodeTable then
		local nNumberPrefix = "";
		if rEffectComp.mod ~= 0 then
			nNumberPrefix = tostring(rEffectComp.mod);
		end
		TableManager.processTableRoll("rollon", nNumberPrefix .. " " .. rEffectComp.remainder[1]);
		-- end	
	end
	if #(rEffectComp.dice) == 0 and rEffectComp.mod == 0 then
		return;
	end
	
	local rTarget = ActorManager.resolveActor(nodeActor);
	if rEffectComp.type == "REGEN" then
		local rActor = ActorManager.resolveActor(nodeActor);
		local nPercentWounded = ActorHealthManager.getWoundPercent(rActor);
		
		-- If not wounded, then return
		if nPercentWounded <= 0 then
			return;
		end
		-- Regeneration does not work once creature falls below 1 hit point (but only if no specific damage type needed to disable regeneration)
		if nPercentWounded >= 1 and (#(rEffectComp.remainder) == 0) then
			return;
		end
		
		local rAction = {};
		rAction.label = "Regeneration";
		rAction.clauses = {};
		
		local aClause = {};
		aClause.dice = rEffectComp.dice;
		aClause.modifier = rEffectComp.mod;
		table.insert(rAction.clauses, aClause);
		
		local rRoll = ActionHeal.getRoll(nil, rAction);
		if EffectManager.isGMEffect(nodeActor, nodeEffect) then
			rRoll.bSecret = true;
		end
		ActionsManager.actionDirect(nil, "heal", { rRoll }, { { rTarget } });
	elseif rEffectComp.type == "TEMPO" then
		local rAction = {};
		rAction.label = "Automatic temp HP";
		rAction.clauses = {};
		rAction.subtype = "temp";
		
		local aClause = {};
		aClause.dice = rEffectComp.dice;
		aClause.modifier = rEffectComp.mod;
		table.insert(rAction.clauses, aClause);
		
		local rRoll = ActionHeal.getRoll(nil, rAction);
		if EffectManager.isGMEffect(nodeActor, nodeEffect) then
			rRoll.bSecret = true;
		end
		ActionsManager.actionDirect(nil, "temphp", { rRoll }, { { rTarget } });
	elseif rEffectComp.type == "DMGO" then
		local rAction = {};
		rAction.label = "Ongoing damage";
		rAction.clauses = {};
		
		local aClause = {};
		aClause.dice = rEffectComp.dice;
		aClause.modifier = rEffectComp.mod;
		aClause.dmgtype = string.lower(table.concat(rEffectComp.remainder, ","));
		table.insert(rAction.clauses, aClause);
		
		local rRoll = ActionDamage.getRoll(nil, rAction);
		if EffectManager.isGMEffect(nodeActor, nodeEffect) then
			rRoll.bSecret = true;
		end
		ActionsManager.actionDirect(nil, "damage", { rRoll }, { { rTarget } });
	end
end