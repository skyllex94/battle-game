using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class WeaponInventory : MonoBehaviour {

    public GameObject[] inventory = new GameObject[5];
    public Button WeaponSwitch;
    public GameObject currentWeapon;
    public GameObject PlayerArm;

    public void AddWeapon(GameObject weapon)
    {
        bool weaponAdded = false;
        for (int i = 0; i < inventory.Length; i++)
        {
            if (inventory[i] == null)
            {
                WeaponSwitch.image.overrideSprite = weapon.GetComponent<SpriteRenderer>().sprite;
                if (i >=3) 
                {
                    if ((inventory[i - 3].name == weapon.name) || (inventory[i - 2].name == weapon.name) || (inventory[i - 1].name == weapon.name))
                    {
                        inventory[i] = null;
                    }
                }
                inventory[i] = weapon;
                currentWeapon = inventory[i];
                currentWeapon.GetComponent<WeaponInfo>().remainingCapacity = currentWeapon.GetComponent<WeaponInfo>().startCapacity;
                currentWeapon.GetComponent<WeaponInfo>().fillerCount = currentWeapon.GetComponent<WeaponInfo>().startFillerCount;
                weaponAdded = true;
                break;
            }
        }
        if (!weaponAdded)
        {
            Debug.Log("Inventory full!");
        }
    }

    public void SwitchWeapon()
    {
            // If stuck with a broader range of ifs, you can try the "switch-case" function
            if (currentWeapon == inventory[0] && inventory[1] != null)
            {
                currentWeapon = inventory[1];
                PlayerArm = GameObject.FindGameObjectWithTag("PlayerArm");
                PlayerArm.transform.Find("WeaponSlot").gameObject.GetComponent<WeaponManager>().UpdateWeapon(currentWeapon);
                return;
            }
            // Second weapon switching statements
            if (currentWeapon == inventory[1] && inventory[2] != null && inventory[0].name != currentWeapon.name)
            {
                currentWeapon = inventory[2];
                PlayerArm = GameObject.FindGameObjectWithTag("PlayerArm");
                PlayerArm.transform.Find("WeaponSlot").gameObject.GetComponent<WeaponManager>().UpdateWeapon(currentWeapon);
                return;
            }
            if (currentWeapon == inventory[1] && inventory[2] == null)
            {
                currentWeapon = inventory[0];
                PlayerArm = GameObject.FindGameObjectWithTag("PlayerArm");
                PlayerArm.transform.Find("WeaponSlot").gameObject.GetComponent<WeaponManager>().UpdateWeapon(currentWeapon);
                return;
            }
            // Third weapon switching statements
            if (currentWeapon == inventory[2])
            {
                currentWeapon = inventory[0];
                PlayerArm = GameObject.FindGameObjectWithTag("PlayerArm");
                PlayerArm.transform.Find("WeaponSlot").gameObject.GetComponent<WeaponManager>().UpdateWeapon(currentWeapon);
                return;
            }
    }

    public void RemoveWeapon(GameObject remove_weapon)
    {
        for (int i = 0; i < inventory.Length; i++)
        {
            if (inventory[i] == remove_weapon)
            {
                    inventory[i] = null;
                    if (inventory[i + 1] != null)
                    {
                        inventory[i] = inventory[i + 1];
                        if (inventory[i + 2] == null)
                        {
                            inventory[i + 1] = null;
                        }
                        if (inventory[i + 2] != null)
                        {
                            inventory[i + 1] = inventory[i + 2];
                            if (inventory[i + 3] == null)
                            {
                                inventory[i + 2] = null;
                            }
                            if (inventory[i + 3] != null)
                            {
                                inventory[i + 2] = inventory[i + 3];
                                if (inventory[i + 4] == null)
                                {
                                    inventory[i + 3] = null;
                                }
                                if (inventory[i + 4] != null)
                                {
                                    inventory[i + 3] = inventory[i + 4];
                                    if (inventory[i + 5] == null)
                                    {
                                        inventory[i + 4] = null;
                                    }
                                    if (inventory[i + 5] != null)
                                    {
                                        inventory[i + 4] = inventory[i + 5];
                                    }
                                }
                            }
                        }
                        currentWeapon = inventory[i];
                        PlayerArm = GameObject.FindGameObjectWithTag("PlayerArm");
                        PlayerArm.transform.Find("WeaponSlot").gameObject.GetComponent<WeaponManager>().UpdateWeapon(currentWeapon);
                    }
                    else if (inventory[i + 1] == null)
                    {
                        currentWeapon = inventory[i - 1];
                        PlayerArm = GameObject.FindGameObjectWithTag("PlayerArm");
                        PlayerArm.transform.Find("WeaponSlot").gameObject.GetComponent<WeaponManager>().UpdateWeapon(currentWeapon);
                    }
                break;
            }
        }
    }
}
