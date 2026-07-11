/datum/unit_test/ipc_construction_head_validation

/datum/unit_test/ipc_construction_head_validation/Run()
	var/obj/item/ipc_core/core = allocate(/obj/item/ipc_core)
	core.stomach = new /obj/item/organ/internal/stomach/synth(core)
	core.lungs = new /obj/item/organ/internal/lungs/synth(core)
	core.heart = new /obj/item/organ/internal/heart/synth(core)
	core.liver = new /obj/item/organ/internal/liver/synth(core)
	core.core_wired = TRUE
	core.core_secured = TRUE
	core.l_arm = new /obj/item/bodypart/arm/left/ipc(core)
	core.r_arm = new /obj/item/bodypart/arm/right/ipc(core)
	core.l_leg = new /obj/item/bodypart/leg/left/ipc(core)
	core.r_leg = new /obj/item/bodypart/leg/right/ipc(core)

	var/obj/item/bodypart/head/ipc/head = new(core)
	core.head = head
	var/obj/item/organ/internal/eyes/synth/eyes = allocate(/obj/item/organ/internal/eyes/synth)
	eyes.forceMove(head)
	head.ipc_eyes = eyes
	head.ipc_ears = new /obj/item/organ/internal/ears/synth(head)
	head.ipc_tongue = new /obj/item/organ/internal/tongue/robot/synth(head)
	head.antennae = new /obj/item/organ/external/antennae/ipc(head)
	head.wired = TRUE
	head.secured = TRUE

	TEST_ASSERT(head.check_completion(), "A fully populated IPC head did not report complete.")
	TEST_ASSERT(core.check_body_completion(), "A fully populated IPC core did not accept its completed head.")

	var/obj/item/organ/internal/eyes/synth/removed_eyes = head.ipc_eyes
	removed_eyes.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!head.secured, "Removing a component from a secured IPC head did not invalidate its secured state.")

	// A stale or externally modified secured flag must not let a stripped head pass chassis validation.
	head.secured = TRUE
	TEST_ASSERT(!head.check_completion(), "An IPC head missing its eyes still reported complete.")
	TEST_ASSERT(!core.check_body_completion(), "An IPC core accepted a stripped head solely because its secured flag was set.")
