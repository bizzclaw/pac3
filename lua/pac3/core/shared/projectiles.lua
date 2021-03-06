local enable = CreateConVar("pac_sv_projectiles", 0, bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE))

do -- projectile entity
	local ENT = {}
	
	ENT.Type = "anim"
	ENT.Base = "base_anim"
	ENT.ClassName = "pac_projectile"
	
	function ENT:SetupDataTables()
		self:SetDTBool(0, "AimDir")	
	end
	
	if CLIENT then
		function ENT:Draw()
			if self.dt.AimDir then 
				self:SetRenderAngles(self:GetVelocity():Angle()) 
			end 
		end
	end
	
	if SERVER then
			
		function ENT:SetData(ply, pos, ang, part)			

			if part.Sphere then
				self:PhysicsInitSphere(math.Clamp(part.Radius, 1, 30))
			else
				self:PhysicsInitBox(Vector(1,1,1) * - math.Clamp(part.Radius, 1, 30), Vector(1,1,1) * math.Clamp(part.Radius, 1, 30))
			end
						
			local phys = self:GetPhysicsObject()
			phys:EnableGravity(part.Gravity)
			phys:AddVelocity((ang:Forward() + (VectorRand():Angle():Forward() * part.Spread)) * part.Speed * 1000)
			phys:EnableCollisions(part.Collisions)	
			phys:SetDamping(part.Damping, 0)
			phys:SetMass(part.Mass)
			
			self.dt.AimDir = part.AimDir
			
			self.part_data = part
		end
		
		if CLIENT then
			
			function ENT:Think()
					
				if self.Sticky and not self.pac_projectile_stuck then
					
					local trace = util.QuickTrace(self:GetPos(), self:GetVelocity() * -10, ent)
					
					if trace.Hit then
						local phys = ent:GetPhysicsObject()
						phys:EnableGravity(false)
						phys:EnableMotion(false)
						phys:SetPos(trace.HitPos)
						phys:SetAngles(trace.HitNormal:Angle())
						self.dt.AimDir = false
						self.pac_projectile_stuck = true
					end
				end
				
				self:NextThink(CurTime())
				return true
			end
		end
		
		function ENT:Touch(ent)
			--if ent:IsValid() and (ent:IsPlayer() or ent:IsNPC()) then
			--	print(ent)
			--	self:GetPhysicsObject():SetVelocity(Vector(0,0,0))
			--end
		end
		
		function ENT:PhysicsCollide(data)
			if self.part_data and self.part_data.Sticky and data.HitEntity:IsWorld() then
				local phys = self:GetPhysicsObject()
				phys:SetVelocity(Vector(0,0,0))
				phys:Sleep()
				phys:EnableMotion(false)
			end
		end
	end
	
	scripted_ents.Register(ENT, ENT.ClassName)
end

if SERVER then
	for key, ent in pairs(ents.FindByClass("pac_projectile")) do
		ent:Remove()
	end
	
	util.AddNetworkString("pac_projectile")
	util.AddNetworkString("pac_projectile_attach")
		
	net.Receive("pac_projectile", function(len, ply)			
		if not enable:GetBool() then return end
	
		local pos = net.ReadVector()
		local ang = net.ReadAngle()
			
		local part = net.ReadTable()

		if pos:Distance(ply:EyePos()) > 200 * ply:GetModelScale() then
			pos = ply:EyePos()
		end
			
		ply.pac_projectiles = ply.pac_projectiles or {}		
		if table.Count(ply.pac_projectiles) >= 30 then
			return
		end		
		
		timer.Simple(part.Delay, function()				
			local ent = ents.Create("pac_projectile")
			ent:SetModel("models/props_junk/popcan01a.mdl")
			
			ent:SetPos(pos)
			ent:SetAngles(ang)
			ent:Spawn()
			
			if not part.CollideWithOwner then 
				ent:SetOwner(ply)
			end
			
			ent:SetData(ply, pos, ang, part)
			
			ent:SetPhysicsAttacker(ply)
				
			timer.Simple(math.Clamp(part.LifeTime, 0, 10), function()
				SafeRemoveEntity(ent)
			end)	
				
			net.Start("pac_projectile_attach")
				net.WriteEntity(ply)
				net.WriteEntity(ent)
				net.WriteString(part.UniqueID)
			net.Broadcast()
		end)
	end)
end