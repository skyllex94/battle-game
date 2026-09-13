using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class WeaponPickUp : MonoBehaviour {

    public GameObject[] weapons;
    public GameObject weaponHere;
    public GameObject PlayerArm;
    public GameObject PlayerCharacter;
    WeaponInventory weap_invent;

    private WeaponInfo weaponInfo;
    private Slider playerAmmoSlider;
    private Button weaponSwitch;

	void Start () {
        weaponHere = weapons[Random.Range(0, weapons.Length)];
        GetComponent<SpriteRenderer>().sprite = weaponHere.GetComponent<SpriteRenderer>().sprite;
        GetComponent<Transform>().localScale = weaponHere.transform.localScale;
        if (weaponHere.GetComponent<SpriteRenderer>().sprite.name == "future_gun")
        {
            GetComponent<BoxCollider2D>().size = new Vector2(6, 2);
        }
        if (weaponHere.GetComponent<SpriteRenderer>().sprite.name == "Gun")
        {
            GetComponent<BoxCollider2D>().size = new Vector2(1, 1);
        }
        playerAmmoSlider = Slider.FindObjectOfType<Slider>();
        weaponSwitch = Button.FindObjectOfType<Button>();
	}
	
	void OnTriggerEnter2D (Collider2D other)
    {
        Player player = other.GetComponent<Player>();
        if (player != null)
        {
            if ((GameObject.Find("Player") || (GameObject.Find("Player(Clone)")) && GameObject.FindGameObjectWithTag("Allies")))
            {
                PlayerCharacter = player.gameObject;
                weap_invent = PlayerCharacter.GetComponent<WeaponInventory>();
                for (int i = 0; i < weap_invent.inventory.Length; i++)
                {
                    if (weap_invent.inventory[i] == weaponHere)
                    {
                        if (weaponSwitch.image.overrideSprite == weaponHere.GetComponent<SpriteRenderer>().sprite)
                        {
                            weaponInfo = weaponHere.GetComponent<WeaponInfo>();
                            weaponInfo.remainingCapacity = weaponInfo.maxCapacity;
                            playerAmmoSlider.value = weaponInfo.maxCapacity;
                        }
                        else
                        {
                            for (int j = 0; j < weap_invent.inventory.Length; j++)
                            {
                                if (weaponHere.name == weap_invent.inventory[j].name)
                                {
                                    weaponInfo = weap_invent.inventory[j].GetComponent<WeaponInfo>();
                                    weaponInfo.remainingCapacity = weaponInfo.maxCapacity;
                                    Destroy(gameObject);
                                    return;
                                }
                            }
                        }
                        Destroy(gameObject);
                        return;
                    }
                }
            }
            PlayerArm = GameObject.FindGameObjectWithTag("PlayerArm");
            PlayerArm.transform.Find("WeaponSlot").gameObject.GetComponent<WeaponManager>().UpdateWeapon(weaponHere);
            Destroy(gameObject);
        }
    }
}
