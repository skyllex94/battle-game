using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Base : MonoBehaviour {

    [SerializeField]
    private StatusIndicator statusIndicator;

    public class BaseStats
    {
        public int maxHealth = 500;
        private int _curHealth;
        public int curHealth
        {
            get { return _curHealth; }
            set { _curHealth = Mathf.Clamp(value, 0, maxHealth); }
        }
        public void Init()
        {
            curHealth = maxHealth;
        }
    }

    public BaseStats Stats = new BaseStats();

    void Start()
    {   //Initialize the stats for the object and set a statusbar indication
        Stats.Init();
        if (statusIndicator != null)
        {
            statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
        }
    }

    public void DamageBase(int damage)
    {
        Stats.curHealth -= damage;
        if (Stats.curHealth <= 0)
        {
            GameMaster.DestroyBase(this);
        }
        if (statusIndicator != null)
        {
            statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
        }
    } 
}
