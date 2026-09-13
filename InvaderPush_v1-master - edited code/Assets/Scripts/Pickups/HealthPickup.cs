using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class HealthPickup : MonoBehaviour {

    public int healthAmount;

    void OnTriggerEnter2D(Collider2D other)
    {
        if (other.tag == "Allies" && (other.name == "Player" || other.name == "Player(Clone)"))
        {
            Player playerHealth = other.gameObject.GetComponent<Player>();
            playerHealth.AddHealth(healthAmount);
            Destroy(gameObject);
        }
    }
}
