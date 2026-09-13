using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityStandardAssets._2D;

[RequireComponent(typeof(Platformer2DUserControl))]
public class Player : MonoBehaviour {

    public int fallBoundary = -20;
    PlayerStats Stats;

    [SerializeField]
    private StatusIndicator statusIndicator;

    void Start()
    {
        Stats = PlayerStats.instance;
        Stats.curHealth = Stats.maxHealth;
        if (statusIndicator == null) {
            statusIndicator = StatusIndicator.FindObjectOfType<StatusIndicator>();
        }
        else 
        {
           statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
        }
        InvokeRepeating("RegenHealth", Stats.HealthRegenRate, Stats.HealthRegenRate);
    }

    void RegenHealth()
    {
        Stats.curHealth += 2;
        statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
    }

    void Update ()
    {
        if (transform.position.y <= fallBoundary)
        {
            DamagePlayer(99999);
        }
    }

    public void DamagePlayer(int damage)
    {
        Stats.curHealth -= damage;
        if (Stats.curHealth <= 0)
        {
            GameMaster.KillPlayer(this);
        }
        statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
    }

    public void AddHealth(int health)
    {
        Stats.curHealth += health;
        if (Stats.curHealth > Stats.maxHealth)
        {
            Stats.curHealth = Stats.maxHealth;
        }
        statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
    }
}
