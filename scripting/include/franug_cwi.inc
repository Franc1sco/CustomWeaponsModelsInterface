/**
 * Set a custom model to a weapon.
 *
 * @param weaponindex            Weapon index for set model.
 * @param modelindex          Model index to set.
 * @param client           Client owned of weapon (0 = no client).
 * 
 * @noreturn			       
 */
native CWI_SetWeapon(weaponindex, modelindex, client=0);



/**
 * Remove the custom model to a weapon.
 *
 * @param weaponindex            Weapon index for remove the custom model.
 * @param client           Client owned of weapon (0 = no client).
 * 
 * @noreturn			       
 */
native CWI_DelWeapon(weaponindex, client=0);