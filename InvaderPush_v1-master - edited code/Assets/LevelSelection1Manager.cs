using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class LevelSelection1Manager : MonoBehaviour {

    public GameObject dialog;

    void Start()
    {
        dialog.SetActive(false);
    }
    public void StartLevel1()
    {
        SceneManager.LoadScene("ConfigurationUI");
    }

    public void CloseDialog() 
    {
        dialog.SetActive(false);
    }

    public void OpenDialog()
    {
        dialog.SetActive(true);
    }
}
