using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlayerWeapon : MonoBehaviour {

    public GameObject bulletPrefab;
    public Sprite gunSprite;
    private Transform firePoint;

    private WeaponInfo weaponInfo;
    
	void Start () 
    {
        firePoint = transform.Find("FirePoint");
        //weaponInfo = this.gameObject.GetComponent<WeaponInfo>();
        //weaponInfo.fillerCount = weaponInfo.startFillerCount;
	}

    public void Shoot()
    {
        Instantiate(bulletPrefab, firePoint.position, firePoint.rotation);
    }
}
