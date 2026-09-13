using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class AmmoPickUp : MonoBehaviour {


	void OnTriggerEnter2D (Collider2D other)
    {
        Player player = other.GetComponent<Player>();
        if (player != null)
        {
            other.GetComponentInChildren<WeaponManager>().ReloadWeapon();
            Destroy(transform.root.gameObject);
        }
    }
}
