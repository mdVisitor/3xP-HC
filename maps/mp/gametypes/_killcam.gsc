#include maps\mp\gametypes\_hud_util;

init()
{
	precacheString(&"PLATFORM_PRESS_TO_SKIP");
	precacheString(&"PLATFORM_PRESS_TO_RESPAWN");
	precacheShader("white");
	
	level.killcam = maps\mp\gametypes\_tweakables::getTweakableValue( "game", "allowkillcam" );
	
	if( level.killcam )
		setArchive(true);
}

killcam(
	attackerNum, // entity number of the attacker
	killcamentity, // entity number of the attacker's killer entity aka helicopter or airstrike
	sWeapon, // killing weapon
	predelay, // time between player death and beginning of killcam
	offsetTime, // something to do with how far back in time the killer was seeing the world when he made the kill; latency related, sorta
	respawn, // will the player be allowed to respawn after the killcam?
	maxtime, // time remaining until map ends; the killcam will never last longer than this. undefined = no limit
	perks, // the perks the attacker had at the time of the kill
	attacker // entity object of attacker
)
{
	// monitors killcam and hides HUD elements during killcam session
	//if ( !level.splitscreen )
	//	self thread killcam_HUD_off();
	
	self endon("disconnect");
	self endon("spawned");
	level endon("game_ended");

	if(attackerNum < 0)
		return;

	if(isDefined(sWeapon) && isPlayer(attacker) && isDefined(attacker.pers) && isDefined(attacker.pers["laser"]) && attacker.pers["laser"] && isSubStr(sWeapon,"reflex"))
		self setClientDvar("cg_laserforceon",1);
	else
		self setClientDvar("cg_laserforceon",0);
	if (getdvar("scr_killcam_time") == "") {
		if (sWeapon == "artillery_mp")
			camtime = 1.3;
		else if ( !respawn ) // if we're not going to respawn, we can take more time to watch what happened
			camtime = 5.0;
		else if (sWeapon == "frag_grenade_mp")
			camtime = 4.5; // show long enough to see grenade thrown
		else
			camtime = 2.5;
	}
	else
		camtime = getdvarfloat("scr_killcam_time");
	
	if (isdefined(maxtime)) {
		if (camtime > maxtime)
			camtime = maxtime;
		if (camtime < .05)
			camtime = .05;
	}
	
	// time after player death that killcam continues for
	if (getdvar("scr_killcam_posttime") == "")
		postdelay = 2;
	else {
		postdelay = getdvarfloat("scr_killcam_posttime");
		if (postdelay < 0.05)
			postdelay = 0.05;
	}

	if(sWeapon == "frag_grenade_mp" || sWeapon == "frag_grenade_short_mp" || sWeapon == "claymore_mp" || sWeapon == "c4_mp" ) 
	  	self setClientDvar("cg_airstrikeKillCamDist",25);
	else 
		self setClientDvar("cg_airstrikeKillCamDist",200);
	/* timeline:
	
	|        camtime       |      postdelay      |
	|                      |   predelay    |
	
	^ killcam start        ^ player death        ^ killcam end
	                                       ^ player starts watching killcam
	
	*/
	
	killcamlength = camtime + postdelay;
	
	// don't let the killcam last past the end of the round.
	if (isdefined(maxtime) && killcamlength > maxtime)
	{
		// first trim postdelay down to a minimum of 1 second.
		// if that doesn't make it short enough, trim camtime down to a minimum of 1 second.
		// if that's still not short enough, cancel the killcam.
		if (maxtime < 2)
			return;

		if (maxtime - camtime >= 1) {
			// reduce postdelay so killcam ends at end of match
			postdelay = maxtime - camtime;
		}
		else {
			// distribute remaining time over postdelay and camtime
			postdelay = 1;
			camtime = maxtime - 1;
		}
		
		// recalc killcamlength
		killcamlength = camtime + postdelay;
	}

	killcamoffset = camtime + predelay;
	
	self notify ( "begin_killcam", getTime() );
	
	self.sessionstate = "spectator";
	self.spectatorclient = attackerNum;
	self.killcamentity = killcamentity;
	self.archivetime = killcamoffset;
	self.killcamlength = killcamlength;
	self.psoffsettime = offsetTime;

	// ignore spectate permissions
	self allowSpectateTeam("allies", true);
	self allowSpectateTeam("axis", true);
	self allowSpectateTeam("freelook", true);
	self allowSpectateTeam("none", true);
	
	// wait till the next server frame to allow code a chance to update archivetime if it needs trimming
	wait 0.05;

	if ( self.archivetime <= predelay ) // if we're not looking back in time far enough to even see the death, cancel
	{
		self.sessionstate = "dead";
		self.spectatorclient = -1;
		self.killcamentity = -1;
		self.archivetime = 0;
		self.psoffsettime = 0;
		
		return;
	}
	
	self.killcam = true;

	if ( !isdefined( self.kc_skiptext ) )
	{
		self.kc_skiptext = newClientHudElem(self);
		self.kc_skiptext.archived = false;
		self.kc_skiptext.x = 0;
		self.kc_skiptext.alignX = "center";
		self.kc_skiptext.alignY = "middle";
		self.kc_skiptext.horzAlign = "center_safearea";
		self.kc_skiptext.vertAlign = "top";
		self.kc_skiptext.sort = 1; // force to draw after the bars
		self.kc_skiptext.font = "objective";
		self.kc_skiptext.foreground = true;
		
		if ( level.splitscreen )
		{
			self.kc_skiptext.y = 34;
			self.kc_skiptext.fontscale = 1.6;
		}
		else
		{
			self.kc_skiptext.y = 60;
			self.kc_skiptext.fontscale = 2;
		}
	}
	if ( respawn )
		self.kc_skiptext setText(&"PLATFORM_PRESS_TO_RESPAWN");
	else
		self.kc_skiptext setText(&"PLATFORM_PRESS_TO_SKIP");
		
	self.kc_skiptext.alpha = 1;

	if ( !level.splitscreen )
	{
		if ( !isdefined( self.kc_timer ) )
		{
			self.kc_timer = createFontString( "objective", 2.0 );
			if ( level.console )
				self.kc_timer setPoint( "BOTTOM", undefined, 0, -80 );
			else
				self.kc_timer setPoint( "BOTTOM", undefined, 0, -60 );
			self.kc_timer.archived = false;
			self.kc_timer.foreground = true;
			/*
			self.kc_timer.x = 0;
			self.kc_timer.y = -32;
			self.kc_timer.alignX = "center";
			self.kc_timer.alignY = "middle";
			self.kc_timer.horzAlign = "center_safearea";
			self.kc_timer.vertAlign = "bottom";
			self.kc_timer.fontScale = 2.0;
			self.kc_timer.sort = 1;
			*/
		}
		
		self.kc_timer.alpha = 1;
		self.kc_timer setTenthsTimer(camtime);
		/*
		self showPerk( 0, perks[0], -10 );
		self showPerk( 1, perks[1], -10 );
		self showPerk( 2, perks[2], -10 );*/
	}

	self thread HonorPlayer(attacker);
/*
	self.top_bg = duffman\_common::addTextHud( self, 0, 0, 1, "center", "top", "center", "top", 1.8, -1 );
 	self.top_bg setShader("white",1000,112);
 	self.top_bg.color = (0,0,0);
 	self.top_bg.alpha = .7;

 	self.bottom_bg = duffman\_common::addTextHud( self, 0, 0, 1, "center", "bottom", "center", "bottom", 1.8, -1 );
	self.bottom_bg setShader("white",1000,112);
 	self.bottom_bg.color = (0,0,0);
 	self.bottom_bg.alpha = .7;
*/
	self thread spawnedKillcamCleanup();
	self thread endedKillcamCleanup();
	self thread waitSkipKillcamButton();
	self thread waitKillcamTime();

	self waittill("end_killcam");

	if(isDefined(self.player_rating))
		self.player_rating destroy();

	/*if(isDefined(self.top_bg))
		self.top_bg destroy();

	if(isDefined(self.bottom_bg))
		self.bottom_bg destroy();
*/
	if(isDefined(self) && isDefined(self.pers["forceLaser"]) && self.pers["forceLaser"]) 
		self setClientDvar("cg_laserforceon",1);
	else 
		self setClientDvar("cg_laserforceon",0);

	self endKillcam();

	self.sessionstate = "dead";
	self.spectatorclient = -1;
	self.killcamentity = -1;
	self.archivetime = 0;
	self.psoffsettime = 0;
}

HonorPlayer(attacker) {
	self endon("disconnect");
	attacker endon("disconnect");
	self endon("end_killcam");
	self.player_rating = duffman\_common::addTextHud( self, 0, 0, 1, "center", "middle", "center", "top", 1.8, 999 );
	self.player_rating.y = 90;
	self.player_rating.showboth = 1;

	self.player_rating thread SwitchText(self,attacker);

	while(self SecondaryOffhandButtonPressed())
		wait .05;

	while(!self SecondaryOffhandButtonPressed())
		wait .05;

	self.player_rating.showboth = 0;

	//if(isDefined(self.player_rating))	
	//	self.player_rating thread duffman\_common::fadeOut(.5);

	attacker.score += 10;
	attacker maps\mp\gametypes\_rank::GiveRankXp("honor",10);
	attacker.pers["honor"]++;
	attacker duffman\_common::iPrintSmall("GOT_HONORED","NAME",self.name);
}

SwitchText(owner,attacker) {
	self endon("death");
	attacker endon("disconnect");
	owner endon("disconnect");
	start = (randomInt(2));
	while(1) {
		if(start && self.showboth) {
			self.label = owner duffman\_common::getLangString("HONOR_PLAYER");
			self SetPlayerNameString(attacker);
		}
		else  {
			self.label = owner duffman\_common::getLangString("CURRENT_HONOR");
			self setValue(attacker.pers["honor"]);
		}
		start = !start;
		self FadeOverTime(.5);
		self.alpha = 1;
		wait .5;
		self FadeOverTime(.5);
		self.alpha = 0;
		wait .5;		
	}
}

waitKillcamTime()
{
	self endon("disconnect");
	self endon("end_killcam");

	wait(self.killcamlength - 0.05);
	self notify("end_killcam");
}

waitSkipKillcamButton()
{
	self endon("disconnect");
	self endon("end_killcam");

	while(self useButtonPressed())
		wait .05;

	while(!(self useButtonPressed()))
		wait .05;

	self notify("end_killcam");
}

endKillcam()
{
	if(isDefined(self.kc_skiptext))
		self.kc_skiptext destroy();
	if(isDefined(self.kc_timer))
		self.kc_timer destroy();
	if(isDefined(self.player_rating))
		self.player_rating destroy();
	
	if ( !level.splitscreen )
	{
		self hidePerk( 0 );
		self hidePerk( 1 );
		self hidePerk( 2 );
	}
	self.killcam = undefined;
	
	self thread maps\mp\gametypes\_spectating::setSpectatePermissions();
}

spawnedKillcamCleanup()
{
	self endon("end_killcam");
	self endon("disconnect");

	self waittill("spawned");
	self endKillcam();
}

spectatorKillcamCleanup( attacker )
{
	self endon("end_killcam");
	self endon("disconnect");
	attacker endon ( "disconnect" );

	attacker waittill ( "begin_killcam", attackerKcStartTime );
	waitTime = max( 0, (attackerKcStartTime - self.deathTime) - 50 );
	wait (waitTime);
	self endKillcam();
}

endedKillcamCleanup()
{
	self endon("end_killcam");
	self endon("disconnect");

	level waittill("game_ended");

	/*if(isDefined(self.top_bg))
		self.top_bg destroy();

	if(isDefined(self.bottom_bg))
		self.bottom_bg destroy();*/
	self endKillcam();
}
