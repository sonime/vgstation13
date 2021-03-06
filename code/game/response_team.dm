//STRIKE TEAMS
//Thanks to Kilakk for the admin-button portion of this code.

var/list/response_team_members = list()
var/global/send_emergency_team = 0 // Used for automagic response teams
                                   // 'admin_emergency_team' for admin-spawned response teams
var/ert_base_chance = 10 // Default base chance. Will be incremented by increment ERT chance.
var/can_call_ert

/client/proc/response_team()
	set name = "Dispatch Emergency Response Team"
	set category = "Special Verbs"
	set desc = "Send an emergency response team to the station"

	if(!holder)
		to_chat(usr, "<span class='warning'>Only administrators may use this command.</span>")
		return
	if(!ticker)
		to_chat(usr, "<span class='warning'>The game hasn't started yet!</span>")
		return
	if(ticker.current_state == 1)
		to_chat(usr, "<span class='warning'>The round hasn't started yet!</span>")
		return
	if(send_emergency_team)
		to_chat(usr, "<span class='warning'>Central Command has already dispatched an emergency response team!</span>")
		return
	if(alert("Do you want to dispatch an Emergency Response Team?",,"Yes","No") != "Yes")
		return
	if(get_security_level() != "red") // Allow admins to reconsider if the alert level isn't Red
		switch(alert("The station is not in red alert. Do you still want to dispatch a response team?",,"Yes","No"))
			if("No")
				return
	var/ert_reason = stripped_input(usr, "Please give a reason for calling the ERT.", "ERT Reason")
	if(send_emergency_team)
		to_chat(usr, "<span class='warning'>Looks like somebody beat you to it!</span>")
		return

	message_admins("[key_name_admin(usr)] is dispatching an Emergency Response Team. Reason given: [ert_reason]")
	log_admin("[key_name(usr)] used Dispatch Response Team. Reason given is: [ert_reason]")
	trigger_armed_response_team(1,ert_reason)


client/verb/JoinResponseTeam()
	set category = "OOC"

	if(istype(usr,/mob/dead/observer) || istype(usr,/mob/new_player))
		if(!send_emergency_team)
			to_chat(usr, "No emergency response team is currently being sent.")
			return
		if(jobban_isbanned(usr, "Syndicate") || jobban_isbanned(usr, "Emergency Response Team") || jobban_isbanned(usr, "Security Officer"))
			to_chat(usr, "<font color=red><b>You are jobbanned from the emergency reponse team!")
			return

		if(response_team_members.len > 5)
			to_chat(usr, "The emergency response team is already full!")


		for (var/obj/effect/landmark/L in landmarks_list) if (L.name == "ERT")
			L.name = null//Reserving the place.
			var/new_name = copytext(sanitize(input(usr, "Pick a name","Name") as null|text), 1, MAX_MESSAGE_LEN)
			if(!new_name)//Somebody changed his mind, place is available again.
				L.name = "ERT"
				return
			var/leader_selected = isemptylist(response_team_members)
			var/mob/living/carbon/human/new_commando = create_response_team(L.loc, leader_selected, new_name)
			qdel(L)
			L = null
			message_admins("[key_name(usr)] has joined the Emergency Response Team.")
			new_commando.mind.key = usr.key
			new_commando.key = usr.key

			to_chat(new_commando, "<span class='notice'>You are [!leader_selected?"a member":"the <B>LEADER</B>"] of an Emergency Response Team, a type of military division, under CentComm's service. There is a code red alert on [station_name()], you are tasked to go and fix the problem.</span>")
			to_chat(new_commando, "<b>You should first gear up and discuss a plan with your team. More members may be joining, don't move out before you're ready.")
			if(!leader_selected)
				to_chat(new_commando, "<b>As member of the Emergency Response Team, you answer only to your leader and CentComm officials.</b>")
			else
				to_chat(new_commando, "<b>As leader of the Emergency Response Team, you answer only to CentComm, and have authority to override the Captain where it is necessary to achieve your mission goals. It is recommended that you attempt to cooperate with the captain where possible, however.")
			if(ticker.mode.ert_reason)
				to_chat(new_commando, "<b>The communication from the station indicated that the reason you were called is '[ticker.mode.ert_reason]'.")

			ticker.mode.ert += new_commando.mind
			return

	else
		to_chat(usr, "You need to be an observer or new player to use this.")

// returns a number of dead players in %
proc/percentage_dead()
	var/total = 0
	var/deadcount = 0
	for(var/mob/living/carbon/human/H in mob_list)
		if(H.client) // Monkeys and mice don't have a client, amirite?
			if(H.stat == 2)
				deadcount++
			total++

	if(total == 0)
		return 0
	else
		return round(100 * deadcount / total)

// counts the number of antagonists in %
proc/percentage_antagonists()
	var/total = 0
	var/antagonists = 0
	for(var/mob/living/carbon/human/H in mob_list)
		if(is_special_character(H) >= 1)
			antagonists++
		total++

	if(total == 0)
		return 0
	else
		return round(100 * antagonists / total)

// Increments the ERT chance automatically, so that the later it is in the round,
// the more likely an ERT is to be able to be called.
proc/increment_ert_chance()
	while(send_emergency_team == 0) // There is no ERT at the time.
		if(get_security_level() == "green")
			ert_base_chance += 1
		if(get_security_level() == "blue")
			ert_base_chance += 2
		if(get_security_level() == "red")
			ert_base_chance += 3
		if(get_security_level() == "delta")
			ert_base_chance += 10           // Need those big guns
		sleep(600 * 3) // Minute * Number of Minutes


proc/trigger_armed_response_team(var/force = 0, var/reason)
	if(!can_call_ert && !force)
		return
	if(send_emergency_team)
		return

	var/send_team_chance = ert_base_chance // Is incremented by increment_ert_chance.
	send_team_chance += 2*percentage_dead() // the more people are dead, the higher the chance
	send_team_chance += percentage_antagonists() // the more antagonists, the higher the chance
	send_team_chance = min(send_team_chance, 100)

	if(force)
		send_team_chance = 100

	// there's only a certain chance a team will be sent
	if(!prob(send_team_chance))
		command_alert(/datum/command_alert/ert_fail)
		can_call_ert = 0 // Only one call per round, ladies.
		return

	command_alert(/datum/command_alert/ert_success)
	if(reason)
		ticker.mode.ert_reason = reason
	for(var/mob/M in player_list)
		if(istype(M, /mob/dead/observer))
			to_chat(M, "<span class='interface big'><span class='bold'>An Emergency Response Team has been called! Consider joining up:</span> \
				(Verbs -> OOC -> JoinResponseTeam, or <a href='?src=\ref[M];joinresponseteam=1'>click here.</a>)</span>")


	can_call_ert = 0 // Only one call per round, gentleman.
	send_emergency_team = 1

	spawn(600 * 5)
		send_emergency_team = 0 // Can no longer join the ERT.

	var/nuke_code
	for(var/obj/machinery/nuclearbomb/nuke in machines)
		nuke_code = nuke.r_code
	var/obj/item/weapon/paper/P = new
	P.info = "Your orders, Commander, are to use all means necessary to return the station to a survivable condition.<br>To this end, you have been provided with the best tools we can give in the three areas of Medicine, Engineering, and Security. The nuclear authorization code is: <b>[ nuke_code ? nuke_code : "No Nuke Found, Request Another!"]</b>. Be warned, if you detonate this without good reason, we will hold you to account for damages. Memorise this code, and then burn this message."
	P.name = "Emergency Nuclear Code, and ERT Orders"
	for (var/obj/effect/landmark/A in landmarks_list)
		if (A.name == "nukecode")
			P.forceMove(A.loc)
			qdel(A)
			A = null
			continue

/client/proc/create_response_team(obj/spawn_location, leader_selected = 0, commando_name)


//	to_chat(usr, "<span class='warning'>ERT has been temporarily disabled. Talk to a coder.</span>")
	//return

	var/mob/living/carbon/human/M = new(null)
	response_team_members |= M

	//todo: god damn this.
	//make it a panel, like in character creation
	var/new_facial = input("Please select facial hair color.", "Character Generation") as color
	if(new_facial)
		M.r_facial = hex2num(copytext(new_facial, 2, 4))
		M.g_facial = hex2num(copytext(new_facial, 4, 6))
		M.b_facial = hex2num(copytext(new_facial, 6, 8))

	var/new_hair = input("Please select hair color.", "Character Generation") as color
	if(new_facial)
		M.r_hair = hex2num(copytext(new_hair, 2, 4))
		M.g_hair = hex2num(copytext(new_hair, 4, 6))
		M.b_hair = hex2num(copytext(new_hair, 6, 8))

	var/new_eyes = input("Please select eye color.", "Character Generation") as color
	if(new_eyes)
		M.r_eyes = hex2num(copytext(new_eyes, 2, 4))
		M.g_eyes = hex2num(copytext(new_eyes, 4, 6))
		M.b_eyes = hex2num(copytext(new_eyes, 6, 8))

	var/new_tone = input("Please select skin tone level: 1-220 (1=albino, 35=caucasian, 150=black, 220='very' black)", "Character Generation")  as text

	if (!new_tone)
		new_tone = 35
	M.s_tone = max(min(round(text2num(new_tone)), 220), 1)
	M.s_tone =  -M.s_tone + 35

	// hair
	var/list/all_hairs = typesof(/datum/sprite_accessory/hair) - /datum/sprite_accessory/hair
	var/list/hairs = list()

	// loop through potential hairs
	for(var/x in all_hairs)
		var/datum/sprite_accessory/hair/H = new x // create new hair datum based on type x
		hairs.Add(H.name) // add hair name to hairs
		qdel(H) // delete the hair after it's all done
		H = null

//	var/new_style = input("Please select hair style", "Character Generation")  as null|anything in hairs
//hair
	var/new_hstyle = input(usr, "Select a hair style", "Grooming")  as null|anything in hair_styles_list
	if(new_hstyle)
		M.h_style = new_hstyle

	// facial hair
	var/new_fstyle = input(usr, "Select a facial hair style", "Grooming")  as null|anything in facial_hair_styles_list
	if(new_fstyle)
		M.f_style = new_fstyle

	// if new style selected (not cancel)
/*	if (new_style)
		M.h_style = new_style

		for(var/x in all_hairs) // loop through all_hairs again. Might be slightly CPU expensive, but not significantly.
			var/datum/sprite_accessory/hair/H = new x // create new hair datum
			if(H.name == new_style)
				M.h_style = H // assign the hair_style variable a new hair datum
				break
			else
				del(H) // if hair H not used, delete. BYOND can garbage collect, but better safe than sorry

	// facial hair
	var/list/all_fhairs = typesof(/datum/sprite_accessory/facial_hair) - /datum/sprite_accessory/facial_hair
	var/list/fhairs = list()

	for(var/x in all_fhairs)
		var/datum/sprite_accessory/facial_hair/H = new x
		fhairs.Add(H.name)
		del(H)

	new_style = input("Please select facial style", "Character Generation")  as null|anything in fhairs

	if(new_style)
		M.f_style = new_style
		for(var/x in all_fhairs)
			var/datum/sprite_accessory/facial_hair/H = new x
			if(H.name == new_style)
				M.f_style = H
				break
			else
				del(H)
*/
	var/new_gender = alert(usr, "Please select gender.", "Character Generation", "Male", "Female")
	if (new_gender)
		if(new_gender == "Male")
			M.setGender(MALE)
		else
			M.setGender(FEMALE)
	//M.rebuild_appearance()
	M.update_hair()
	M.update_body()
	M.check_dna(M)

	M.real_name = commando_name
	M.name = commando_name
	M.age = !leader_selected ? rand(23,35) : rand(35,45)

	M.dna.ready_dna(M)//Creates DNA.

	//Creates mind stuff.
	M.mind = new
	M.mind.current = M
	M.mind.original = M
	M.mind.assigned_role = "MODE"
	M.mind.special_role = "Response Team"
	if(!(M.mind in ticker.minds))
		ticker.minds += M.mind//Adds them to regular mind list.
	M.forceMove(spawn_location)
	M.equip_strike_team(leader_selected)
	return M

/mob/living/carbon/human/proc/equip_strike_team(leader_selected = 0)


	//Special radio setup
	equip_to_slot_or_del(new /obj/item/device/radio/headset/ert(src), slot_ears)

	//Adding Camera Network
	var/obj/machinery/camera/camera = new /obj/machinery/camera(src) //Gives all the commandos internals cameras.
	camera.network = "CREED"
	camera.c_tag = real_name

	//Basic Uniform
	equip_to_slot_or_del(new /obj/item/clothing/under/ert(src), slot_w_uniform)
	equip_to_slot_or_del(new /obj/item/device/flashlight(src), slot_l_store)
	equip_to_slot_or_del(new /obj/item/weapon/gun/energy/gun(src), slot_belt)

	//Glasses
	equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/sechud(src), slot_glasses)

	//Shoes & gloves
	equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(src), slot_shoes)
	equip_to_slot_or_del(new /obj/item/clothing/gloves/swat(src), slot_gloves)

	//Backpack
	equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/security(src), slot_back)
	equip_to_slot_or_del(new /obj/item/weapon/storage/box/survival/ert(src), slot_in_backpack)
	equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/regular(src), slot_in_backpack)

	if(leader_selected)
		equip_to_slot_or_del(new /obj/item/weapon/card/shuttle_pass/ERT(src), slot_in_backpack)

	var/obj/item/weapon/card/id/W = new(src)
	W.assignment = "Emergency Responder[leader_selected ? " Leader" : ""]"
	W.registered_name = real_name
	W.name = "[real_name]'s ID Card ([W.assignment])"
	if(!leader_selected)
		W.access = get_centcom_access("Emergency Responder")
		W.icon_state = "ERT_empty"	//placeholder until revamp
	else
		W.access = get_centcom_access("Emergency Responders Leader")
		W.icon_state = "ERT_leader"
	equip_to_slot_or_del(W, slot_wear_id)
	var/obj/item/weapon/implant/loyalty/L = new/obj/item/weapon/implant/loyalty(src)
	L.imp_in = src
	L.implanted = 1
	var/datum/organ/external/affected = get_organ(LIMB_HEAD)
	affected.implants += L
	L.part = affected

	return 1

//debug verb (That is horribly coded, LEAVE THIS OFF UNLESS PRIVATELY TESTING. Seriously.
/*client/verb/ResponseTeam()
	set category = "Admin"
	if(!send_emergency_team)
		send_emergency_team = 1*/
