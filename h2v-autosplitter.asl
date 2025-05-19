// Halo 2 Vista/Project Cartographer Autosplitter
// By Cambid

state ("halo2") {}

init {

    version = modules.First().FileVersionInfo.FileVersion;

    vars.watchers_h2 = new MemoryWatcherList();
    vars.watchers_h2xy = new MemoryWatcherList();
    vars.watchers_h2fade = new MemoryWatcherList();

    vars.watchers_h2.Add(new StringWatcher(new DeepPointer(0x47CF0C), 3) { Name = "levelname" });
    vars.watchers_h2.Add(new MemoryWatcher<uint>(new DeepPointer(0x4C06E4, 0x8)) { Name = "tickcounter" });
    vars.watchers_h2.Add(new MemoryWatcher<float>(new DeepPointer(0x48227C, 0x0)) { Name = "letterbox" });
    vars.watchers_h2.Add(new MemoryWatcher<byte>(new DeepPointer(0x48227C, 0x5)) { Name = "fadebyte" });
    vars.watchers_h2.Add(new MemoryWatcher<byte>(new DeepPointer(0x4119A4)) { Name = "bspstate" });
    vars.watchers_h2.Add(new MemoryWatcher<bool>(new DeepPointer(0x48224E)) { Name = "map_reset" });
    vars.watchers_h2.Add(new MemoryWatcher<bool>(new DeepPointer(0x482256)) { Name = "game_won" });
    vars.watchers_h2.Add(new MemoryWatcher<bool>(new DeepPointer(0xA4AFDD)) { Name = "loading" });

    vars.H2_coords = 0x4A8504;

    vars.watchers_h2xy.Add(new MemoryWatcher<float>(new DeepPointer(vars.H2_coords)) { Name = "xpos" });
    vars.watchers_h2xy.Add(new MemoryWatcher<float>(new DeepPointer(vars.H2_coords + 0x4)) { Name = "ypos" });
    vars.watchers_h2xy.Add(new MemoryWatcher<float>(new DeepPointer(vars.H2_coords + 0x8)) { Name = "zpos" });

    vars.H2_fade = 0x4CE860;

    vars.watchers_h2fade.Add(new MemoryWatcher<uint>(new DeepPointer(vars.H2_fade, 0x0)) { Name = "fadetick" });
    vars.watchers_h2fade.Add(new MemoryWatcher<ushort>(new DeepPointer(vars.H2_fade, 0x4)) { Name = "fadelength" });
    //vars.watchers_h2fade.Add(new MemoryWatcher<byte>(new DeepPointer(vars.H2_fade + 0x6)) { Name = "fadebyte" });


}

startup {
    // Switch to game time
    vars.aslName = "H2VSplitter";
	if(timer.CurrentTimingMethod == TimingMethod.RealTime)
	{
		var timingMessage = MessageBox.Show(
			"This game uses Game Time (time without loads) as the main timing method. "+
			"LiveSplit is currently set to show Real Time (time INCLUDING loads). "+
			"Would you like the timing method to be set to Game Time for you?",
			vars.aslName+" | LiveSplit",
			MessageBoxButtons.YesNo,MessageBoxIcon.Question
		);
		if (timingMessage == DialogResult.Yes)
		timer.CurrentTimingMethod = TimingMethod.GameTime;
	}

    // Global vars
    vars.loading = false;
    vars.startedlevel = "000";
    vars.varsreset = false;
    vars.forcesplit = false;
    vars.armorymemes = false;
    vars.levelswaptime = TimeSpan.Zero;
    vars.dirtybsps_byte = new List<byte>();

    vars.H2_tgjreadyflag = false;
    vars.H2_tgjreadytime = 0;
    vars.lastinternal = false;

    vars.fadescale = 0.167;

    vars.H2_levellist = new Dictionary<string, byte[]> {
		{"01a", new byte[] {  }}, //armory
		{"01b", new byte[] { 2, 0, 3 }}, //cairo
		{"03a", new byte[] { 1, 2 }}, //os
		{"03b", new byte[] { 1 }}, //metro
		{"04a", new byte[] { 3, 0 }}, //arby - 2, 0, 4, and 1 are using in cs 
		{"04b", new byte[] { 0, 2, 1, 5 }}, //here - 0 in cs, 3 at start, returns to 0 later gah - maybe skip the 4 split cos it's just for like 10s when cables cut
		{"05a", new byte[] { 1 }}, //dh - flahses between 2 and 0 in cs
		{"05b", new byte[] { 1, 2 }}, //reg - 0 in cs. skipping 3 & 4 since it's autoscroller
		{"06a", new byte[] { 1, 2 }}, //si - 0 then 3 in cs, starts on 0
		{"06b", new byte[] { 1, 2, 3 }}, //qz- there are more besides this but all during autoscroller
		{"07a", new byte[] { 1, 2, 3, 4, 5 }}, //gm - 7 & 0 in cs
		{"08a", new byte[] { 1, 0 }}, //up -- hits 0 again after 1. ignoring skipable
		{"07b", new byte[] { 1, 2, 4 }}, //HC -- none if doing HC skip
		{"08b", new byte[] { 0, 1, 3 }}, //TGJ -- starts 0 and in cs, then goes to 1, then 0, then 1, then 0, then 3 (skipping 2 cos it's skippable)
	};


    // Settings
    settings.Add("ILmode", false, "Individual Level mode");
	settings.SetToolTip("ILmode", "Makes the timer start, reset and ending split at the correct IL time for each level");

	settings.Add("bspmode", false, "Split on unique \"Loading... Done\"'s ", "ILmode");
	settings.SetToolTip("bspmode", "Split on unique bsp loads (\"Loading... Done\") within levels. \n" +
		"You'll need to add a lot of extra splits for this option, see this spreadsheet for a count of how many per level of each game (outdated): \n" +
		"tinyurl.com/bspsplit"
	);
}

update {
    vars.watchers_h2.UpdateAll(game);
    vars.watchers_h2fade.UpdateAll(game);

    if (settings["bspmode"]) {
        vars.watchers_h2xy.UpdateAll(game);
    }

    //copypasta var reset code
    if (timer.CurrentPhase == TimerPhase.Running && !vars.varsreset) {
        vars.varsreset = true;
    }
    else if (timer.CurrentPhase == TimerPhase.NotRunning && vars.varsreset) {
        vars.loading = false;
        vars.varsreset = false;
        vars.startedlevel = "000";
        vars.forcesplit = false;
        vars.armorymemes = false;
        vars.levelswaptime = TimeSpan.Zero;
        vars.dirtybsps_byte.Clear();

        vars.H2_tgjreadyflag = false;
        vars.H2_tgjreadytime = 0;
        vars.lastinternal = false;
    }

    if (!vars.loading) { //if not currently loading, determine whether we need to be

        if (vars.armorymemes) {
            TimeSpan temp = new TimeSpan(0, 0, 0, 1, 350);
            if (vars.levelswaptime + temp < timer.CurrentTime.RealTime) {
                vars.loading = true;
                vars.forcesplit = true;
                vars.armorymemes = false;
                vars.levelswaptime = TimeSpan.Zero;
            }
        }

        else if (vars.watchers_h2["levelname"].Current != "mai" && vars.watchers_h2["levelname"].Old != "mai") { //between level loads.
            string H2_checklevel = vars.watchers_h2["levelname"].Current;
            switch (H2_checklevel) {
                case "01a": //Armory
                    if (vars.watchers_h2["game_won"].Current && !vars.watchers_h2["game_won"].Old) {
                        vars.armorymemes = true;
                        vars.levelswaptime = timer.CurrentTime.RealTime;
                    }
                break;

                case "01b": //Cairo
                case "03a": //Outskirts
                case "03b": //Metropolis
                case "04a": //Arbiter
                case "05a": //Delta Halo
                case "06a": //Sacred Icon
                case "07a": //Gravemind
                case "08a": //Uprising
                case "07b": //High Charity
                    if ((vars.watchers_h2["tickcounter"].Current > 60 && vars.watchers_h2["fadebyte"].Current == 1 && vars.watchers_h2["fadebyte"].Old == 1 && vars.watchers_h2["letterbox"].Current > 0.96 && vars.watchers_h2["letterbox"].Old <= 0.96 && vars.watchers_h2["letterbox"].Old != 0)) {
                        vars.loading = true;
                        if(settings["ILmode"]) {
                            vars.forcesplit = true;
                        }
                    }
                break;

                case "04b": //Oracle
                case "05b": //Regret
                    if (!vars.lastinternal && (vars.watchers_h2["fadebyte"].Current == 1 && vars.watchers_h2["letterbox"].Current > 0.96 && vars.watchers_h2["letterbox"].Old <= 0.96 && vars.watchers_h2["letterbox"].Old != 0)) {
                        if (vars.watchers_h2["levelname"].Current == "04b" && vars.watchers_h2["bspstate"].Current == 5) {
                            vars.lastinternal = true;
                        }
                        else if (vars.watchers_h2["levelname"].Current == "05b" && vars.watchers_h2["bspstate"].Current == 2) {
                            vars.lastinternal = true;
                        }
                    }
                    else if ((vars.watchers_h2["tickcounter"].Current > 60 && vars.lastinternal && vars.watchers_h2["fadebyte"].Current == 1 && vars.watchers_h2["fadebyte"].Old == 1 && vars.watchers_h2["letterbox"].Current > 0.96 && vars.watchers_h2["letterbox"].Old <= 0.96 && vars.watchers_h2["letterbox"].Old != 0)) {
                        vars.loading = true;	
                        vars.lastinternal = false;
                        if(settings["ILmode"]) {
                            vars.forcesplit = true;
                        }
                    }
                break;

                case "06b":	//Quarantine Zone
                    if ((vars.watchers_h2["tickcounter"].Current > 60 && vars.watchers_h2["fadebyte"].Current == 1 && vars.watchers_h2["fadebyte"].Old == 1 && vars.watchers_h2["letterbox"].Current > 0.96 && vars.watchers_h2["letterbox"].Old <= 0.96 && vars.watchers_h2["letterbox"].Old != 0)) {
                        if (vars.watchers_h2["bspstate"].Current == 4 || vars.watchers_h2["loading"].Current) {
                            vars.loading = true;
                            if(settings["ILmode"]) {
                                vars.forcesplit = true;
                            }
                        }
                    }
                break;

                case "mai":
                    if (vars.watchers_h2["loading"].Current && !vars.watchers_h2["loading"].Current) {
                        vars.loading = true;
                    }
                break;
            }
        }
        else if (vars.watchers_h2["loading"].Current && !vars.watchers_h2["loading"].Old) {	//main menu to level loads.
            vars.loading = true;
        }
    }
    else {	//if currently loading, determine whether we need not be
        if (vars.watchers_h2["levelname"].Current != "mai" && vars.watchers_h2["levelname"].Old != "mai" && !vars.watchers_h2["loading"].Current && vars.H2_levellist.ContainsKey(vars.watchers_h2["levelname"].Current)) { //between level loads.
            if (vars.watchers_h2["levelname"].Current == "03a") {
                if (!vars.watchers_h2["loading"].Current) {
                    if (vars.watchers_h2["fadebyte"].Current == 1 && vars.watchers_h2["bspstate"].Current == 0 && vars.watchers_h2["tickcounter"].Current > 10 && vars.watchers_h2["tickcounter"].Current < 100) {
                        if (vars.watchers_h2fade["fadelength"].Current > 15 && vars.watchers_h2["tickcounter"].Current >= (vars.watchers_h2fade["fadetick"].Current + (uint)Math.Round(vars.watchers_h2fade["fadelength"].Current * vars.fadescale))) {
                            vars.loading = false;
                        }
                    }
                    else if (vars.watchers_h2["fadebyte"].Current == 0 && vars.watchers_h2["tickcounter"].Current > vars.watchers_h2["tickcounter"].Old && vars.watchers_h2["tickcounter"].Current > 10) {
                        vars.loading = false;
                    }
                }
            }
            else if (vars.watchers_h2["levelname"].Current == "01a") {
                if (vars.watchers_h2["tickcounter"].Current >= 13 &&  vars.watchers_h2["tickcounter"].Current < 15) {
                    vars.loading = false;
                }
                else if (vars.watchers_h2["fadebyte"].Current == 0 && vars.watchers_h2["tickcounter"].Current > vars.watchers_h2["tickcounter"].Old && vars.watchers_h2["tickcounter"].Current > 10) {
                    vars.loading = false;
                }
            }
            else {
                if (vars.watchers_h2["fadebyte"].Current == 0 && vars.watchers_h2["fadebyte"].Old == 1 && vars.watchers_h2["bspstate"].Current != 255) {
                    vars.loading = false;
                    vars.lastinternal = false;
                }
                else if (vars.watchers_h2["fadebyte"].Current == 0 && vars.watchers_h2["tickcounter"].Current > vars.watchers_h2["tickcounter"].Old && vars.watchers_h2["tickcounter"].Current > 10 && vars.watchers_h2["bspstate"].Current != 255) {
                    vars.loading = false;
                }
            }
        }
    }
    //TGJ cutscene rubbish
    if (vars.watchers_h2["levelname"].Current == "08b" && !vars.H2_tgjreadyflag) {
        if (vars.watchers_h2["bspstate"].Current == 3) {
            vars.H2_tgjreadyflag = true;
            vars.H2_tgjreadytime = vars.watchers_h2["tickcounter"].Current;
            print ("H2 tgj ready flag set");
        } 
    }

}

start {
    if (vars.watchers_h2["levelname"].Current == "01a" && vars.watchers_h2["tickcounter"].Current >= 13 &&  vars.watchers_h2["tickcounter"].Current < 15) { //start on armory
        vars.startedlevel = "01a";
        return true;
    }
    else if (vars.watchers_h2["levelname"].Current == "01b" && !vars.watchers_h2["loading"].Current && vars.watchers_h2["fadebyte"].Current == 0 && vars.watchers_h2["fadebyte"].Old == 1 && vars.watchers_h2["tickcounter"].Current < 30) { //start on cairo
        vars.startedlevel = "01b";
        return true;
    }
    else if (settings["ILmode"]) {
        if (vars.watchers_h2["fadebyte"].Current == 0 && vars.watchers_h2["fadebyte"].Old == 1 && vars.watchers_h2["bspstate"].Current != 255) {
            vars.startedlevel = vars.watchers_h2["levelname"].Current;
            return true;
        }
    }
}

split {
    if (vars.forcesplit) {
        vars.forcesplit = false;
        return true;
    }
    else if (vars.watchers_h2["levelname"].Current == "08b") {
        if (vars.watchers_h2["fadebyte"].Current == 1 && vars.watchers_h2["letterbox"].Current > 0.96 && vars.watchers_h2["letterbox"].Old <= 0.96  && vars.watchers_h2["letterbox"].Old != 0 && vars.H2_tgjreadyflag && ( vars.watchers_h2["tickcounter"].Current > (vars.H2_tgjreadytime + 300))) {
            return true;
        }
    }
    else if (!settings["ILmode"] && vars.watchers_h2["game_won"].Current && !vars.watchers_h2["game_won"].Old && vars.watchers_h2["levelname"].Current != "00a" && vars.watchers_h2["levelname"].Current != "01a") {
        return true;
    }

    // This is straight copypasta code by Burnt from the MCC autosplitter. I assume it should be mostly interchangable.
    if (settings["bspmode"]) {
        string checklevel = vars.watchers_h2["levelname"].Current;
        switch (checklevel) {
            case "01b":
                if (vars.watchers_h2["bspstate"].Current != vars.watchers_h2["bspstate"].Old && Array.Exists((byte[]) vars.H2_levellist[checklevel], x => x == vars.watchers_h2["bspstate"].Current) && !(vars.dirtybsps_byte.Contains(vars.watchers_h2["bspstate"].Current))) {
                    if (vars.watchers_h2["bspstate"].Current == 0 && !(vars.dirtybsps_byte.Contains(2)))	{ // hacky workaround for the fact that the level starts on bsp 0 and returns there later
                        return false;
                    }
                    vars.dirtybsps_byte.Add(vars.watchers_h2["bspstate"].Current);
                    return true;
                }
            break;
            
            case "03a":
            case "03b":
            case "05a":
            case "05b":
            case "06a":
            case "06b":
            case "07a":
            case "07b":
                if (vars.watchers_h2["bspstate"].Current != vars.watchers_h2["bspstate"].Old && Array.Exists((byte[]) vars.H2_levellist[checklevel], x => x == vars.watchers_h2["bspstate"].Current) && !(vars.dirtybsps_byte.Contains(vars.watchers_h2["bspstate"].Current))) {
                    vars.dirtybsps_byte.Add(vars.watchers_h2["bspstate"].Current);
                    return true;
                }
            break;
            
            case "04a":
                if (vars.watchers_h2["bspstate"].Current != vars.watchers_h2["bspstate"].Old && Array.Exists((byte[]) vars.H2_levellist[checklevel], x => x == vars.watchers_h2["bspstate"].Current) && !(vars.dirtybsps_byte.Contains(vars.watchers_h2["bspstate"].Current))) {
                    if (vars.watchers_h2["bspstate"].Current == 0 && !(vars.dirtybsps_byte.Contains(3))) { // hacky workaround for the fact that the level starts on bsp 0 and returns there later
                        return false;
                    }
                    vars.dirtybsps_byte.Add(vars.watchers_h2["bspstate"].Current);
                    return true;
                }
            break;
            
            case "04b":
                if (vars.watchers_h2["bspstate"].Current == 3 && !(vars.dirtybsps_byte.Contains(3))) {
                    vars.dirtybsps_byte.Add(3);	//prevent splitting on starting bsp
                }
                if (vars.watchers_h2["bspstate"].Current != vars.watchers_h2["bspstate"].Old && Array.Exists((byte[]) vars.H2_levellist[checklevel], x => x == vars.watchers_h2["bspstate"].Current) && !(vars.dirtybsps_byte.Contains(vars.watchers_h2["bspstate"].Current))) {
                    if (vars.watchers_h2["bspstate"].Current == 0 && (vars.dirtybsps_byte.Contains(3))) {
                        return true;
                    } // hacky workaround for the fact that the level starts on bsp 0 and returns there later
                    
                    vars.dirtybsps_byte.Add(vars.watchers_h2["bspstate"].Current);
                    return true;
                }
            break;
            
            case "08a":
                if (vars.watchers_h2["bspstate"].Current != vars.watchers_h2["bspstate"].Old && Array.Exists((byte[]) vars.H2_levellist[checklevel], x => x == vars.watchers_h2["bspstate"].Current) && !(vars.dirtybsps_byte.Contains(vars.watchers_h2["bspstate"].Current))) {
                    if (vars.watchers_h2["bspstate"].Current == 0 && !(vars.dirtybsps_byte.Contains(1))) {	// hacky workaround for the fact that the level starts on bsp 0 and returns there later
                        return false;
                    }
                    vars.dirtybsps_byte.Add(vars.watchers_h2["bspstate"].Current);
                    return true;
                }
            break;

            case "08b":
            print("yes");
                //TGJ -- starts 0 and in cs, then goes to 1, then 0, then 1, then 0, then 3 (skipping 2 cos it's skippable)
                //so I have jank logic cos it does so much backtracking and backbacktracking
                if (vars.watchers_h2["bspstate"].Current != vars.watchers_h2["bspstate"].Old) {                    
                    byte checkbspstate = vars.watchers_h2["bspstate"].Current;
                    switch (checkbspstate) {
                        case 1:
                            if (!(vars.dirtybsps_byte.Contains(1)) && vars.watchers_h2xy["xpos"].Current > -2 && vars.watchers_h2xy["xpos"].Current < 5 && vars.watchers_h2xy["ypos"].Current > -35 && vars.watchers_h2xy["ypos"].Current < -15) {
                                vars.dirtybsps_byte.Add(1);
                                return true;
                            }
                            else if (!(vars.dirtybsps_byte.Contains(21)) && (vars.dirtybsps_byte.Contains(10))  && vars.watchers_h2xy["xpos"].Current > 15 && vars.watchers_h2xy["xpos"].Current < 25 && vars.watchers_h2xy["ypos"].Current > 15 && vars.watchers_h2xy["ypos"].Current < 30) {
                                vars.dirtybsps_byte.Add(21);
                                return true;
                            }
                        
                        break;
                        
                        case 0:
                            if (!(vars.dirtybsps_byte.Contains(10)) && vars.watchers_h2xy["xpos"].Current > -20 && vars.watchers_h2xy["xpos"].Current < -10 && vars.watchers_h2xy["ypos"].Current > 20 && vars.watchers_h2xy["ypos"].Current < 30) {
                                vars.dirtybsps_byte.Add(10);
                                return true;
                            }
                            else if (!(vars.dirtybsps_byte.Contains(20)) && (vars.dirtybsps_byte.Contains(21))  && vars.watchers_h2xy["xpos"].Current > 45 && vars.watchers_h2xy["xpos"].Current < 55 && vars.watchers_h2xy["ypos"].Current > -5 && vars.watchers_h2xy["ypos"].Current < 10) {
                                vars.dirtybsps_byte.Add(20);
                                return true;
                            }
                        break;
                        
                        case 3:
                            if (!(vars.dirtybsps_byte.Contains(3))) {
                                vars.dirtybsps_byte.Add(3);
                                return true;
                            }
                        break;
                        
                        default:
                        break;
                    }
                } 
            break;
            default:
            break;
        }
    }
}

reset {
    if (settings["ILmode"]) {
        return (((vars.watchers_h2["map_reset"].Current && !vars.watchers_h2["map_reset"].Old) || (vars.watchers_h2["levelname"].Current == "mai")) && timer.CurrentPhase != TimerPhase.Ended);
    }
    else if ((vars.watchers_h2["levelname"].Current == "01a" || (vars.watchers_h2["levelname"].Current == "01b" && vars.startedlevel != "01a") || vars.watchers_h2["levelname"].Current == "00a") && timer.CurrentPhase != TimerPhase.Ended) {
        return ((vars.watchers_h2["map_reset"].Current && !vars.watchers_h2["map_reset"].Old) || (!vars.watchers_h2["loading"].Current && vars.watchers_h2["loading"].Old && vars.watchers_h2["tickcounter"].Current < 60));
    }
}

isLoading {
    if (settings["ILmode"]) {
        return false;
    }
    else return vars.loading;
}

gameTime {

}