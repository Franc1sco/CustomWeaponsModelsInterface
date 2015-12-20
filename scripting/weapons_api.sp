#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <cstrike>

#pragma semicolon 1

#define EF_NODRAW 32


new bool:SpawnCheck[MAXPLAYERS+1];
new ClientVM[MAXPLAYERS+1][2];
new bool:IsCustom[MAXPLAYERS+1];

#define VERSION "v1.0.1"

public Plugin:myinfo =
{
	name = "SM Custom Weapons Interface",
	author = "Franc1sco franug",
	description = "",
	version = VERSION,
	url = "http://steamcommunity.com/id/franug"
};

new Handle:trie_weapons;
//new Handle:cvar_reinicio;

public OnPluginStart()
{
    CreateConVar("sm_customweaponsinterface", VERSION, "plugin info", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
    trie_weapons = CreateTrie();
/*     cvar_reinicio = FindConVar("mp_restartgame");
    HookConVarChange(cvar_reinicio,reinicio_hacer); */
	
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_spawn", Event_PlayerSpawn);
    //HookEvent("round_start", Reinicio, EventHookMode_Pre);
    //HookEvent("round_end", Reinicio);
    
    for (new client = 1; client <= MaxClients; client++) 
    { 
        if (IsClientInGame(client)) 
        {
            SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
            
            //find both of the clients viewmodels
            ClientVM[client][0] = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
            
            new PVM = -1;
            while ((PVM = FindEntityByClassname(PVM, "predicted_viewmodel")) != -1)
            {
                if (GetEntPropEnt(PVM, Prop_Send, "m_hOwner") == client)
                {
                    if (GetEntProp(PVM, Prop_Send, "m_nViewModelIndex") == 1)
                    {
                        ClientVM[client][1] = PVM;
                        break;
                    }
                }
            }
        } 
    }
}

public OnPluginEnd()
{
	if(trie_weapons != INVALID_HANDLE) CloseHandle(trie_weapons);
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnEntityCreated(entity, const String:classname[])
{
    if (StrEqual(classname, "predicted_viewmodel", false))
    {
        SDKHook(entity, SDKHook_Spawn, OnEntitySpawned);
    }
}

//find both of the clients viewmodels
public OnEntitySpawned(entity)
{
    new Owner = GetEntPropEnt(entity, Prop_Send, "m_hOwner");
    if ((Owner > 0) && (Owner <= MaxClients))
    {
        if (GetEntProp(entity, Prop_Send, "m_nViewModelIndex") == 0)
        {
            ClientVM[Owner][0] = entity;
        }
        else if (GetEntProp(entity, Prop_Send, "m_nViewModelIndex") == 1)
        {
            ClientVM[Owner][1] = entity;
        }
    }
}

public OnPostThinkPost(client)
{
    static OldWeapon[MAXPLAYERS + 1];
    static OldSequence[MAXPLAYERS + 1];
    static Float:OldCycle[MAXPLAYERS + 1];
    
    new WeaponIndex;
    decl String:arma[8];
    
    //handle spectators
    if (!IsPlayerAlive(client))
    {
        return;
    }
    
    WeaponIndex = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    new Sequence = GetEntProp(ClientVM[client][0], Prop_Send, "m_nSequence");
    new Float:Cycle = GetEntPropFloat(ClientVM[client][0], Prop_Data, "m_flCycle");
    
    if (WeaponIndex <= 0)
    {
        new EntEffects = GetEntProp(ClientVM[client][1], Prop_Send, "m_fEffects");
        EntEffects |= EF_NODRAW;
        SetEntProp(ClientVM[client][1], Prop_Send, "m_fEffects", EntEffects);
        
        IsCustom[client] = false;
            
        OldWeapon[client] = WeaponIndex;
        OldSequence[client] = Sequence;
        OldCycle[client] = Cycle;
        
        return;
    }
    
    //just stuck the weapon switching in here aswell instead of a separate hook
    if (WeaponIndex != OldWeapon[client])
    {
        new armacustom;
        IntToString(WeaponIndex, arma, 8);
        if(GetTrieValue(trie_weapons, arma, armacustom))
        {
            //hide viewmodel
            new EntEffects = GetEntProp(ClientVM[client][0], Prop_Send, "m_fEffects");
            EntEffects |= EF_NODRAW;
            SetEntProp(ClientVM[client][0], Prop_Send, "m_fEffects", EntEffects);
            //unhide unused viewmodel
            EntEffects = GetEntProp(ClientVM[client][1], Prop_Send, "m_fEffects");
            EntEffects &= ~EF_NODRAW;
            SetEntProp(ClientVM[client][1], Prop_Send, "m_fEffects", EntEffects);
            
            //set model and copy over props from viewmodel to used viewmodel
            SetEntProp(ClientVM[client][1], Prop_Send, "m_nModelIndex", armacustom);
            SetEntPropEnt(ClientVM[client][1], Prop_Send, "m_hWeapon", GetEntPropEnt(ClientVM[client][0], Prop_Send, "m_hWeapon"));
            
            SetEntProp(ClientVM[client][1], Prop_Send, "m_nSequence", GetEntProp(ClientVM[client][0], Prop_Send, "m_nSequence"));
            SetEntPropFloat(ClientVM[client][1], Prop_Send, "m_flPlaybackRate", GetEntPropFloat(ClientVM[client][0], Prop_Send, "m_flPlaybackRate"));
            
            IsCustom[client] = true;
        }
        else
        {
            //hide unused viewmodel if the current weapon isn't using it
            new EntEffects = GetEntProp(ClientVM[client][1], Prop_Send, "m_fEffects");
            EntEffects |= EF_NODRAW;
            SetEntProp(ClientVM[client][1], Prop_Send, "m_fEffects", EntEffects);
            
            IsCustom[client] = false;
        }
    }
    else
    {
        if (IsCustom[client])
        {
            //copy the animation stuff from the viewmodel to the used one every frame
            SetEntProp(ClientVM[client][1], Prop_Send, "m_nSequence", GetEntProp(ClientVM[client][0], Prop_Send, "m_nSequence"));
            SetEntPropFloat(ClientVM[client][1], Prop_Send, "m_flPlaybackRate", GetEntPropFloat(ClientVM[client][0], Prop_Send, "m_flPlaybackRate"));
            
            if ((Cycle < OldCycle[client]) && (Sequence == OldSequence[client]))
            {
                SetEntProp(ClientVM[client][1], Prop_Send, "m_nSequence", 0);
            }
        }
    }
    //hide viewmodel a frame after spawning
    if (SpawnCheck[client])
    {
        SpawnCheck[client] = false;
        if (IsCustom[client])
        {
            new EntEffects = GetEntProp(ClientVM[client][0], Prop_Send, "m_fEffects");
            EntEffects |= EF_NODRAW;
            SetEntProp(ClientVM[client][0], Prop_Send, "m_fEffects", EntEffects);
        }
    }
    
    OldWeapon[client] = WeaponIndex;
    OldSequence[client] = Sequence;
    OldCycle[client] = Cycle;
}
//hide viewmodel on death
public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new UserId = GetEventInt(event, "userid");
    new client = GetClientOfUserId(UserId);
    
    new EntEffects = GetEntProp(ClientVM[client][1], Prop_Send, "m_fEffects");
    EntEffects |= EF_NODRAW;
    SetEntProp(ClientVM[client][1], Prop_Send, "m_fEffects", EntEffects);
}

//when a player repsawns at round start after surviving previous round the viewmodel is unhidden
public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new UserId = GetEventInt(event, "userid");
    new client = GetClientOfUserId(UserId);
    
    //use to delay hiding viewmodel a frame or it won't work
    SpawnCheck[client] = true;
}  

/* public Reinicio(Handle:event, const String:name[], bool:dontBroadcast)
{
	ClearTrie(trie_weapons);
} */

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("CWI_SetWeapon", Native_SetWeapon);
	CreateNative("CWI_DelWeapon", Native_DelWeapon);
    
	return APLRes_Success;
}

public Native_SetWeapon(Handle:plugin, argc)
{  
	new index = GetNativeCell(1);
	new model_index = GetNativeCell(2);
	new client = GetNativeCell(3);

	if(client != 0) RestaurarArmaNew(client, index, model_index);
	else 
	{
		decl String:arma[8];
		IntToString(index, arma, 8);
		SetTrieValue(trie_weapons, arma, model_index);
	}
}

public Native_DelWeapon(Handle:plugin, argc)
{  
	decl String:arma[8];
	new index = GetNativeCell(1);
	new client = GetNativeCell(2);
	IntToString(index, arma, 8);

	RemoveFromTrie(trie_weapons, arma);
	
	if(client != 0) RestaurarArma(client, index);
}

RestaurarArma(client, index)
{
	new bool:equipar = false;
	if(Client_GetActiveWeapon(client) == index) equipar = true;
	
	decl String:ClassName[30];
	GetEdictClassname(index, ClassName, sizeof(ClassName));
	new clip = Weapon_GetPrimaryClip(index);
	new ammo = Weapon_GetPrimaryAmmoCount(index);
	RemovePlayerItem(client, index);
	AcceptEntityInput(index, "Kill");
	
	Client_GiveWeaponAndAmmo(client, ClassName, equipar, ammo, -1, clip, -1);

}

RestaurarArmaNew(client, index, model_index)
{
	new bool:equipar = false;
	if(Client_GetActiveWeapon(client) == index) equipar = true;
	
	decl String:ClassName[30];
	GetEdictClassname(index, ClassName, sizeof(ClassName));
	new clip = Weapon_GetPrimaryClip(index);
	new ammo = Weapon_GetPrimaryAmmoCount(index);
	RemovePlayerItem(client, index);
	AcceptEntityInput(index, "Kill");
	
	new newindex = Client_GiveWeaponAndAmmo(client, ClassName, equipar, ammo, -1, clip, -1);
	
	decl String:arma[8];
	IntToString(newindex, arma, 8);
	SetTrieValue(trie_weapons, arma, model_index);

}

/* public Action:CS_OnTerminateRound(&Float:delay, &CSRoundEndReason:reason)
{
	CreateTimer(delay-1.0, Reinicio, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Reinicio(Handle:timer)
{
	Limpiar();
}

public reinicio_hacer(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new valor = StringToInt(newValue);
	if(valor == 0) Limpiar();
} 
Limpiar()
{
	PrintToChatAll("llamado");
	ClearTrie(trie_weapons);
}*/

public OnMapStart()
{
	ClearTrie(trie_weapons);
}

public OnEntityDestroyed(entity)
{
	if(!IsValidEdict(entity) || !IsValidEntity(entity)) return;
	
	decl String:ClassName[64];
	GetEdictClassname(entity, ClassName, sizeof(ClassName));
	if(StrContains(ClassName, "weapon_") == 0)
	{
		decl String:arma[8];
		IntToString(entity, arma, 8);
		RemoveFromTrie(trie_weapons, arma);
		//PrintToChatAll("arma eliminada %i con nombre %s",entity, ClassName);
	}
}