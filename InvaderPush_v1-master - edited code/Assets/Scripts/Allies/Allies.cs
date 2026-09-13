using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Allies : MonoBehaviour {

    [System.Serializable]

    public class AlliesStats
    {
        public int maxHealth = 100;
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
        public int damage = 40;
    }

    public AlliesStats Stats = new AlliesStats();

    [Header("Optional:")]
    [SerializeField]
    private StatusIndicator statusIndicator;

	void Start () 
        {   //Initialize the stats for the object and set a statusbar indication
            Stats.Init();
            if (statusIndicator != null)
            {
                statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
            }
        }

    public void DamageAlly(int damage)
    {
        Stats.curHealth -= damage;
        if (Stats.curHealth <= 0)
        {
            GameMaster.KillAlly(this);
        }
        if (statusIndicator != null)
        {
            statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
        }
    }
}
