using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class WeaponManager : MonoBehaviour {

    public GameObject activeWeapon;
    PlayerWeapon wpn;
    public float fireRate = 0;
    public float timeToFire = 0;
    public WeaponInventory weap_invent;

    //Reload Variables
    public Slider playerAmmoSlider;
    private WeaponInfo weaponInfo;
    public Button WeaponSwitch;
	bool isclickDown;
	void Start () {
        wpn = activeWeapon.GetComponent<PlayerWeapon>();
        weap_invent.AddWeapon(activeWeapon);
        GetComponent<SpriteRenderer>().sprite = wpn.gunSprite;
//      firePoint = wpn.transform.FindChild("FirePoint");

        weaponInfo = weap_invent.inventory[0].GetComponent<WeaponInfo>();
        playerAmmoSlider.maxValue = weaponInfo.maxCapacity;
        playerAmmoSlider.value = weaponInfo.startCapacity;
        weaponInfo.remainingCapacity = weaponInfo.startCapacity;
        weaponInfo.fillerCount = weaponInfo.startFillerCount;
		isclickDown=true;
	}
	
	void Update () 
    {
//        if (!IsPointerOverUIObject())
//		{

			//int t = Input.touchCount;
			//if (Input.GetButtonDown("Fire1")){
		//&& t==2 && Input.GetTouch (t).position.x < Screen.width / 4.5 && Input.GetTouch (t).position.y < Screen.height / 2.5
		//&& Input.GetTouch (1).position.x < Screen.width / 4.5 && Input.GetTouch (1).position.y < Screen.height / 2.5)
		//if (Input.touchCount > 0)

		for (int i = 0; i < Input.touchCount; ++i)
		{
			if (Input.GetTouch(i).phase == TouchPhase.Stationary  &&  isclickDown==true)
			{

				if(!IsPointerOverUIObject()){	
				
					

				if (weaponInfo.fillerCount > 0 )
				{			 
										 if (weaponInfo.remainingCapacity > 0 )
										 {
															
									                        Instantiate(wpn.bulletPrefab, transform.position, transform.rotation);
									                        weaponInfo.remainingCapacity -= 1;
									                        playerAmmoSlider.value = weaponInfo.remainingCapacity;
															isclickDown=false;
															
										}
									     else
									     {
									       	                weaponInfo.fillerCount -= 1;
									                        weaponInfo.remainingCapacity = weaponInfo.maxCapacity;
															
										}
				}
				else
				{	
					weap_invent.RemoveWeapon(weaponInfo.gameObject);
				}

				}
			}else {
				isclickDown=true;
			}
		}
			

	}

    public void UpdateWeapon(GameObject newWeapon)
    {
        if (activeWeapon == newWeapon)
        {
            return;
        }
        for (int i = 0; i < weap_invent.inventory.Length; i++)
        {
            if (weap_invent.inventory[i] != null)
            {
                if (weap_invent.inventory[i].name == newWeapon.name)
                {
                    activeWeapon = newWeapon;
                    GetComponent<Transform>().localScale = newWeapon.GetComponent<Transform>().localScale;
                    wpn = activeWeapon.GetComponent<PlayerWeapon>();
                    GetComponent<SpriteRenderer>().sprite = wpn.gunSprite;
                    WeaponSwitch.image.overrideSprite = wpn.GetComponent<SpriteRenderer>().sprite;

                    weaponInfo = weap_invent.currentWeapon.GetComponent<WeaponInfo>();
                    if (weaponInfo.fillerCount == 0)
                    {
                        playerAmmoSlider.maxValue = weaponInfo.maxCapacity;
                        playerAmmoSlider.value = 0;
                        return;
                    }
                    weaponInfo.fillerCount = weaponInfo.startFillerCount;
                    playerAmmoSlider.maxValue = weaponInfo.maxCapacity;
                    //weaponInfo.remainingCapacity = weaponInfo.startCapacity;
                    playerAmmoSlider.value = weaponInfo.remainingCapacity;
                    return;
                }
            }
        }
        activeWeapon = newWeapon;
        GetComponent<Transform>().localScale = newWeapon.GetComponent<Transform>().localScale;
        weap_invent.AddWeapon(activeWeapon);
        wpn = activeWeapon.GetComponent<PlayerWeapon>();
        GetComponent<SpriteRenderer>().sprite = wpn.gunSprite;

        weaponInfo = weap_invent.currentWeapon.GetComponent<WeaponInfo>();
        if (weaponInfo.fillerCount == 0)
        {
            playerAmmoSlider.maxValue = weaponInfo.maxCapacity;
            playerAmmoSlider.value = 0;
            return;
        }
        weaponInfo.fillerCount = weaponInfo.startFillerCount;
        playerAmmoSlider.maxValue = weaponInfo.maxCapacity;
        //weaponInfo.remainingCapacity = weaponInfo.startCapacity;
        playerAmmoSlider.value = weaponInfo.remainingCapacity;
    }

    public void ReloadWeapon()
    {
        weaponInfo.remainingCapacity = weaponInfo.maxCapacity;
        playerAmmoSlider.value = weaponInfo.remainingCapacity;
        weaponInfo.fillerCount += 1;
    }

    public void RemoveWeapon(GameObject removed_weapon)
    {

    }

    private bool IsPointerOverUIObject()
    {
        PointerEventData eventDataCurrentPosition = new PointerEventData(EventSystem.current);
        eventDataCurrentPosition.position = new Vector2(Input.mousePosition.x, Input.mousePosition.y);
        List<RaycastResult> results = new List<RaycastResult>();
        EventSystem.current.RaycastAll(eventDataCurrentPosition, results);
        return results.Count > 0;
    }
}
