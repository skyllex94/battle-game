using UnityEngine;
using System.Collections;
using System.Collections.Generic;

[RequireComponent(typeof(PlatformerCharacter2D))]
public class PlayerStats : MonoBehaviour {

    public static PlayerStats instance;
    public float HealthRegenRate = 2f;
    public float speedRate = 10f;
    
        public int maxHealth = 100;
        private int _curHealth;
        public int curHealth
        {
            get { return _curHealth; }
            set { _curHealth = Mathf.Clamp(value, 0, maxHealth); }
        }

        void Awake()
        {
            if (instance == null)
            {
                instance = this;
            }
            curHealth = maxHealth;
        }
}
