using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyBase : MonoBehaviour {

    [SerializeField]
    private StatusIndicator statusIndicator;

    public class EnemyBaseStats
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

    public EnemyBaseStats Stats = new EnemyBaseStats();

    void Start()
    { //Initialize the stats for the object and set a statusbar indication
        Stats.Init();
        if (statusIndicator != null)
        {
            statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
        }
        //GameMaster.gm.onPauseMenu += OnPauseMenuActive;
    }

    void OnPauseMenuActive(bool active)
    {
        if (this == null) return;
        GetComponent<EnemyBaseRotation>().enabled = !active;
    }

    public void DamageEnemyBase(int damage)
    {
        Stats.curHealth -= damage;
        if (Stats.curHealth <= 0)
        {
            GameMaster.DestroyEnemyBase(this);
        }
        if (statusIndicator != null)
        {
            statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
        }
    } 
}
